defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message.StatusLine, as: StatusLine
  alias Sippet.DigestAuth, as: DigestAuth

  @moduledoc """

  """
  def start_link(account) do
    transport_name = account.uri.port |> to_charlist() |> List.to_atom()

    proxy =
      with true <- Map.has_key?(account, :outbound_proxy),
           true <- Map.has_key?(account.outbound_proxy, :dns) do
        case account.outbound_proxy.dns do
          "A" ->
            {account.outbound_proxy.host, account.outbound_proxy.port}

          "SRV" ->
            raise ArgumentError, "Cannot use SRV records at this time"

          "NAPTR" ->
            raise ArgumentError, "Cannot use NAPTR records at this time"

          _ ->
            nil
        end
      end

    # start sippet instance based on sip user data
    {:ok, sippet} = Sippet.start_link(name: transport_name)

    # build a
    {:ok, _transport_pid} =
      case account.transport do
        "udp" ->
          Guppi.Transport.start_link(
            name: transport_name,
            address: Guppi.Helpers.local_ip!(),
            port: account.uri.port,
            proxy: proxy
          )
      end

    # register the core process - everything is one per "user"
    Sippet.register_core(transport_name, Guppi.Core)

    # silly mechanism to catch next agent state
    init_state =
      case account.register do
        true ->
          :register

        false ->
          :idle
      end

    # run the agent GenServer
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        sippet: sippet,
        transport: transport_name,
        calls: [],
        cseq: 0
      },
      name: account.name
    )
  end

  @impl true
  def init(agent) do
    # we immediately register the "valid agent" to Guppi.Registry
    case Guppi.register(agent.account.uri.port, agent.account.uri.userinfo) do
      {:ok, _} -> :ok
      error -> Logger.warn(inspect(error))
    end

    # on initialization, should we immediately register or are we clear to transmit?
    case agent.state do
      :register ->
        # GenServer.cast(self(), :register)
        Guppi.Register.start_link(agent)
        {:ok, agent}

      _ ->
        {:ok, agent}
    end
  end

  @impl true
  def handle_info(
        {:authenticate, %Message{start_line: %StatusLine{}, headers: %{cseq: cseq}} = challenge},
        agent
      ) do
    request =
      case cseq do
        {_, :register} ->
          Guppi.Register.make_register(agent)

        _ ->
          raise RuntimeError,
                "#{agent.account.uri.userinfo} was challenged on a method we can't make yet"
      end

    {:ok, auth_request} =
      DigestAuth.make_request(
        request,
        challenge,
        fn _ -> {:ok, agent.account.sip_user, agent.account.sip_password} end,
        []
      )

    case Sippet.send(agent.transport, update_branch(auth_request)) do
      :ok ->
        {:noreply, Map.put_new(agent, :cseq, agent.cseq + 1)}

      {:error, reason} ->
        Logger.warn("could not send auth request: #{reason}")
    end
  end

  @impl true
  def handle_info({:ok, _response, key}, agent) do
    Logger.debug("Got OK: #{key}")

    {:noreply, agent}
  end

  @impl true
  def handle_info(:register, agent) do
    Sippet.send(agent.transport, Guppi.Register.make_register(agent))

    {:noreply, agent}
  end

  @impl true
  def handle_cast(%Message{start_line: %RequestLine{} = _request}, agent) do
    {:noreply, agent}
  end

  @impl true
  def handle_cast({:invite, request, server_key}, agent) do
    Logger.debug("#{server_key}\n#{Message.to_iodata(request)}")

    # we have to wrap this in a try because ExSDP is based on rfc4566, and does not support some parameters being sent by typical video phones
    # and because of the way it's implemented it raises even when we call the version of the function that should not.
    # unsupported params discovered:
    # - sar-supported="#{supported_aspect_ratio_id}"

    changeset = register_call(request.headers.call_id, agent)

    response =
      case validate_offer(request.body) do
        {:ok, _sdp_offer} ->
          Message.to_response(request, 200)
          # |> Message.put_header(:content_type, "application/sdp")
          |> Map.replace!(:body, to_string(Guppi.Media.fake_sdp()))

        {:error, error} ->
          {:error, error}
      end

    # TODO: implement configurable validations?
    # TODO: implement offer/answer via sdp media in reply. this is the critical and final validation. for now we simply accept the session

    Sippet.send(agent.transport, response)

    {:noreply, changeset}
  end

  @impl true
  def handle_cast({:notify, request, _key}, agent) do
    Logger.debug("#{request.start_line.method}: #{inspect(request.body)}")

    Sippet.send(agent.transport, Message.to_response(request, 200))

    {:noreply, agent}
  end

  @impl true
  def handle_cast({:refer, %Message{} = request, _key}, agent) do
    Logger.debug("We got a REFER and shouldn't have?: #{inspect(request)} received a REFER")
    {:noreply, agent}
  end

  @impl true
  def handle_cast({:options, _request, _key}, agent) do
    {:noreply, agent}
  end

  @impl true
  def handle_cast({:cancel, _request, _key}, agent) do
    {:noreply, agent}
  end

  # we need to remove the call from our tracked calls and send a 200 on those cases.
  @impl true
  def handle_cast({:bye, request, client_key}, agent) do
    changeset =
      case Enum.member?(agent.calls, request.headers.call_id) do
        true ->
          Logger.debug("BYE is valid, closing Call: #{request.headers.call_id}")
          # TODO: tear down call resource in future media engine
          Sippet.send(agent.transport, Message.to_response(request, 200))

          Map.update!(
            agent,
            :calls,
            fn calls -> List.delete(calls, request.headers.call_id) end
          )

        false ->
          Logger.warning(
            "got a BYE for a call we don't recognize?\nkey: #{inspect(client_key)}\ncall: #{request.headers.call_id}"
          )

          Sippet.send(agent.transport, Message.to_response(request, 481))
          agent
      end

    {:noreply, changeset}
  end

  @impl true
  def handle_call(:status, _caller, agent), do: {:reply, agent, agent}

  @impl true
  def terminate(_, _) do
    Logger.warn("WHY DID MY GENSERVER STOP")
  end

  defp register_call(call_id, agent) do
    case Enum.member?(agent.calls, call_id) do
      false ->
        Map.update!(
          agent,
          :calls,
          fn calls -> List.insert_at(calls, length(calls), call_id) end
        )

      true ->
        agent
    end
  end

  # updates cseq, via, and from headers for a given request.
  # appropriate for authentication challenges. may be useful elsewhere.
  defp update_branch(request) do
    request
    |> Message.update_header(:cseq, fn {seq, method} ->
      {seq + 1, method}
    end)
    |> Message.update_header_front(:via, fn {ver, proto, hostport, params} ->
      {ver, proto, hostport, %{params | "branch" => Message.create_branch()}}
    end)
    |> Message.update_header(:from, fn {name, uri, params} ->
      {name, uri, %{params | "tag" => Message.create_tag()}}
    end)
  end

  defp validate_offer(body) do
    try do
      sdp = ExSDP.parse!(body)

      IO.inspect(sdp)

      {:ok, sdp}
    rescue
      error ->
        Logger.warn(
          "could not parse sdp, sending 488:\n#{body}\n\nOffending parameter: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def status(username) do
    GenServer.call(username, :status)
  end
end
