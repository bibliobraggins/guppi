defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Guppi.Requests, as: Requests
  alias Guppi.RegisterTimer, as: RegisterTimer

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message.StatusLine, as: StatusLine
  alias Sippet.DigestAuth, as: DigestAuth

  @moduledoc """
    This Module spawns a process that behaves as a "SIP Agent" or SIP aware element,
    and makes it referencable as a named GenServer.
    The idea here is that an Agent will gradually "construct" a %Call{}
    as it processes SIP messages.
    Other interactions like BLF and MWI, and location Registration are possible too.
    Once a Call is constructed, the Call is then able to start it's media endpoints via the Media Module
  """

  def start_link(account) do
    agent_name = String.to_atom(account.uri.userinfo)

    transport = get_transport_name(account.local_port)

    # silly mechanism to catch next agent state
    init_state = get_init_state(account)

    # start the SIP agent
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        transport: transport,
        name: agent_name,
        cseq: 0
      },
      name: agent_name
    )
  end

  defp get_transport_name(input) do
    case input do
      nil ->
        5060

      input when is_integer(input) and input > 0 and input < 65536 ->
        input
    end
    |> to_charlist()
    |> List.to_atom()
  end

  defp get_init_state(account) do
    case account.register do
      true ->
        :register

      false ->
        :idle
    end
  end

  @impl true
  def init(agent) do
    Sippet.start_link(name: agent.transport)

    Guppi.Transport.start_link(
      name: agent.transport,
      address: Guppi.Helpers.local_ip!(),
      port: agent.account.local_port,
      proxy: agent.account.outbound_proxy
    )

    # declare process module handling inbound messages
    Sippet.register_core(agent.transport, Guppi.Core)

    # on initialization, should we immediately register or are we clear to transmit?
    case agent.state do
      :register ->
        # GenServer.cast(self(), :register)
        RegisterTimer.start_link(agent)
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
          RegisterTimer.make_register(agent)

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
        receive do
          {:authenticate, %Message{start_line: %StatusLine{}, headers: %{cseq: _cseq}}} ->
            Logger.warn("Unable to Authenticate: #{agent.name}")
            {:noreply, Map.replace(agent, :state, :idle)}

          _ ->
            {:noreply, agent}
        end

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
    Sippet.send(agent.transport, Requests.register(agent.account, agent.cseq))

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
      sdp_offer = %ExSDP{} ->
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

        create_call(
          request.headers.call_id,
          request.headers.from,
          request.headers.to,
          request.headers.via
        )

        ack_call(request.headers.call_id, agent, sdp_offer)

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

    {:noreply, Map.put_new(agent, :mwi, read: 0, unread: 0)}
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
  def handle_call(:state, _caller, agent), do: {:reply, agent, agent}

  @impl true
  def terminate(_, _) do
    Logger.warn("WHY DID MY GENSERVER STOP")
  end

  defp create_call(call_id, from, to, via) do
    Guppi.Calls.create(call_id, from, to, via)
  end

  defp ack_call(call_id, agent, sdp_offer) do
    call = %Guppi.Call{} = Guppi.Calls.get(call_id)

    ack = Guppi.Requests.ack(agent.account, agent.cseq, call, sdp_offer)

    Logger.debug("Valid Message? #{call_id}:\t", Message.valid?(ack))

    Sippet.send(agent.transport, ack)
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
      ExSDP.parse!(body)
    rescue
      error ->
        Logger.warn(
          "could not parse sdp, sending 488:\n#{body}\n\nOffending parameter: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def status(username) do
    GenServer.call(username, :state)
  end

  def tx_pipeline_options(sdp_offer) do
    [map] =
      Enum.map(sdp_offer.media, fn %ExSDP.Media{} = media ->
        %{port: media.port, address: media.connection_data.address}
      end)

    map
  end
end
