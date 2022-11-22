defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message.StatusLine, as: StatusLine
  alias Sippet.DigestAuth, as: DigestAuth

  @moduledoc """

    :init ->
      :register
               \
            401||407 --> :auth
                        /     \

  """
  def start_link(account) do
    agent_name = account.uri.userinfo |> String.to_atom()

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
    {:ok, sippet} = Sippet.start_link(name: agent_name)

    # build a
    {:ok, _transport_pid} =
      case account.transport do
        "udp" ->
          Guppi.Transport.start_link(
            name: agent_name,
            address: Guppi.Helpers.local_ip!(),
            port: account.uri.port,
            proxy: proxy
          )
      end

    # register the core process - everything is one per "user"
    Sippet.register_core(agent_name, Guppi.Core)

    # silly mechanism to catch next agent state
    init_state =
      case account.register do
        true ->
          :register

        false ->
          :init
      end

    # run the agent GenServer
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        sippet: sippet,
        transport: agent_name,
        cseq: 0,
        pid: self()
      }
    )
  end

  @impl true
  def init(agent) do
    # we immedaitely register the "valid agent" to Guppi.Registry
    case Guppi.register(agent.account) do
      {:ok, _} -> :ok
      error -> Logger.warn(inspect(error))
    end

    # on initialization, should we immediately register or are we clear to transmit?
    case agent.state do
      :register -> GenServer.cast(self(), :register)
    end

    {:ok, agent}
  end

  @impl true
  def handle_cast(:register, agent) do
    Logger.debug("Agent is sending a Registration")
    registration = Guppi.Register.make_register(agent)

    Sippet.send(agent.transport, registration)

    receive do
      {:ok, %Message{start_line: %StatusLine{status_code: 200}}} ->
        :ok

      # we may want to reuse this somewhere. TODO: abstract this to a cleaner "Auth" module
      {:authenticate, %Message{start_line: %StatusLine{status_code: status_code}} = response}
      when status_code in [401, 407] ->
        {:ok, authenticated_request} =
          DigestAuth.make_request(
            registration,
            response,
            fn _ -> {:ok, agent.account.sip_user, agent.account.sip_password} end,
            []
          )

        authenticated_request =
          authenticated_request
          |> Message.update_header(:cseq, fn {seq, method} ->
            {seq + 1, method}
          end)
          |> Message.update_header_front(:via, fn {ver, proto, hostport, params} ->
            {ver, proto, hostport, %{params | "branch" => Message.create_branch()}}
          end)
          |> Message.update_header(:from, fn {name, uri, params} ->
            {name, uri, %{params | "tag" => Message.create_tag()}}
          end)

        Sippet.send(agent.transport, authenticated_request)

      {:error, error} ->
        Logger.critical(inspect(error))
        {:error, error}
    end

    {:noreply, Map.replace(agent, :cseq, agent.cseq + 1)}
  end

  @impl true
  def handle_cast(%Message{start_line: %RequestLine{} = _request}, agent) do
    {:noreply, agent}
  end

  @impl true
  def handle_cast({:invite, request, _server_key}, agent) do
    Logger.debug("Received request: #{inspect(request.start_line)}")

    response =
      %Message{} =
      Message.to_response(request, 200)
      |> Message.put_header(:content_type, "application/sdp")

    Logger.debug(inspect(response))

    {:noreply, Sippet.send(agent.transport, response), agent}
  end

  @impl true
  def handle_cast({:notify, request, _key}, agent) do
    Sippet.send(agent.transport, Message.to_response(request, 200))

    Logger.debug("#{request.start_line.method}: #{inspect(request.body)}")

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

  @impl true
  def handle_cast({:response, _response, key}, agent) do
    Logger.debug("Received Response: #{inspect(key)}")
    {:noreply, agent}
  end

  @impl true
  def handle_cast({:bye, _request, _key}, agent) do
    {:noreply, :not_implemented, agent}
  end

  @impl true
  def handle_cast(:status, agent) do
    {:noreply, agent, agent}
  end

  @impl true
  def handle_cast(:stop, agent) do
    # TODO
    case on_call?(agent) do
      false ->
        {:stop, :normal}

      true ->
        {:noreply, {:error, :on_call, agent.account.uri.authority}}
    end
  end

  # TODO
  defp on_call?(_agent), do: false || true
end
