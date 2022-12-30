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

    children = [
      {Sippet, name: transport_name},
      {Guppi.Transport,
       name: transport_name,
       address: Guppi.Helpers.local_ip!(),
       port: account.uri.port,
       proxy: proxy}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    # declare process module handling inbound messages
    Sippet.register_core(transport_name, Guppi.Core)

    # silly mechanism to catch next agent state
    init_state =
      case account.register do
        true ->
          :register

        false ->
          :idle
      end

    # start the SIP agent
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        transport: transport_name,
        name: String.to_atom(account.uri.userinfo),
        cseq: 0
      },
      name: String.to_atom(account.uri.userinfo)
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

    case Sippet.send(agent.transport, update_via(auth_request)) do
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

    # sdp_string = to_string(Guppi.Media.fake_sdp())
    case validate_offer(request.body) do
      _sdp = %ExSDP{} ->
        response = Message.to_response(request, 200)

        #  Note on SDP: we need to generate an answer in an ACK or PRACK request
        #  upon every 200 OK condition in the case of an INVITE/call

        #  RFC 3261 13.2.2.4:
        #  The UAC core MUST generate an ACK request for each 2xx received from
        #  the transaction layer.  The header fields of the ACK are constructed
        #  in the same way as for any request sent within a dialog (see Section
        #  12) with the exception of the CSeq and the header fields related to
        #  authentication.  The sequence number of the CSeq header field MUST be
        #  the same as the INVITE being acknowledged, but the CSeq method MUST
        #  be ACK.  The ACK MUST contain the same credentials as the INVITE.  If
        #  the 2xx contains an offer (based on the rules above), the ACK MUST
        #  carry an answer in its body.  If the offer in the 2xx response is not
        #  acceptable, the UAC core MUST generate a valid answer in the ACK and
        #  then send a BYE immediately.

        Sippet.send(
          agent.transport,
          response
        )

        register_call(
          request.headers.call_id,
          request.headers.from,
          request.headers.to,
          request.headers.via
        )

        send_ack(request.headers.call_id, agent)

        {:noreply, Map.replace(agent, :cseq, agent.cseq + 1)}

      {:error, reason} ->
        Logger.warn("could not handle incoming call: #{reason} ")

        {:noreply, Map.replace(agent, :cseq, agent.cseq + 1)}
    end
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
  def handle_cast({:cancel, request, _key}, agent) do
    response_code = drop_call(request.headers.call_id)

    Sippet.send(agent.transport, Message.to_response(request, response_code))

    {:noreply, agent}
  end

  # we need to remove the call from our tracked calls and send a 200 on those cases.
  @impl true
  def handle_cast({:bye, request, _client_key}, agent) do
    response_code = drop_call(request.headers.call_id)

    Sippet.send(agent.transport, Message.to_response(request, response_code))

    {:noreply, agent}
  end

  @impl true
  def handle_call(:status, _caller, agent), do: {:reply, agent, agent}

  @impl true
  def terminate(_, _) do
    Logger.warn("WHY DID MY GENSERVER STOP")
  end

  defp register_call(call_id, from, to, via) do
    Guppi.Calls.create(call_id, from, to, via)
  end

  defp drop_call(call_id) do
    case Enum.member?(Guppi.Calls.show(), call_id) do
      true ->
        Guppi.Calls.delete(call_id)
        200

      false ->
        488
    end
  end

  def send_ack(call_id, agent) do
    call = %Guppi.Call{} = Guppi.Calls.get(call_id)

    ack = Guppi.Requests.ack(agent.account, agent.cseq, call)

    # Logger.warn(Message.valid?(ack))

    Sippet.send(agent.transport, ack)
  end

  # updates cseq, via, and from headers for a given request.
  # appropriate for authentication challenges. may be useful elsewhere.
  defp update_via(request) do
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

      sdp
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

  def send_ringing_response(request, transport, sdp_string) do
    provisional =
      Message.to_response(request, 183)
      |> Map.replace!(:body, sdp_string)

    Sippet.send(transport, provisional)
  end

  def tx_pipeline_options(sdp_offer) do
    [map] =
      Enum.map(sdp_offer.media, fn %ExSDP.Media{} = media ->
        %{port: media.port, address: media.connection_data.address}
      end)

    map
  end
end