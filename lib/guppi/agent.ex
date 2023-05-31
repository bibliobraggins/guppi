defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Guppi.Requests, as: Requests
  alias Guppi.RegistrationHandler, as: RegistrationHandler

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.DigestAuth, as: DigestAuth

  @moduledoc """
    This Module spawns a process that behaves as a "SIP Agent" or SIP aware element,
    and makes it referencable as a named GenServer.
    The idea here is that an Agent will gradually "construct" a %Call{}
    as it processes SIP messages.
    Other interactions like BLF and MWI, and location Registration are possible too.
    Once a Call is constructed, the Call is then able to start it's media endpoints via the Media Module
  """

  @spec start_link([
          {:account, atom | %{:register => boolean, :uri => atom | map, optional(any) => any}}
          | {:transport, any},
          ...
        ]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(account: account, transport: transport) do
    name = String.to_atom(account.uri.userinfo)

    # silly mechanism to catch next agent state
    init_state = get_init_state(account.register)

    # start the SIP agent
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        transport: transport,
        name: name,
        cseq: 0,
        messages_waiting: nil
      },
      name: name
    )
  end

  defp get_init_state(register) do
    case register do
      true ->
        :register

      false ->
        :idle
    end
  end

  @impl true
  @spec init(%{
          :account => atom | %{:registration_timer => any, :retries => any, optional(any) => any},
          :name => any,
          optional(any) => any
        }) :: {:ok, map}
  def init(agent) do
    children = [
      %{
        id: RegistrationHandler,
        start: {
          RegistrationHandler,
          :start_link,
          [
            [
              name: agent.name,
              cseq: 0,
              timer: agent.account.registration_timer,
              retries: agent.account.retries
            ]
          ]
        }
      }
    ]

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_all)

    {:ok, Map.put_new(agent, :children, pid)}
  end

  @impl true
  def handle_info({:challenge, %Message{headers: %{cseq: {cseq, method}}} = challenge}, agent)
      when is_integer(cseq) and is_atom(method) do
    agent = Map.replace!(agent, :state, authenticate(challenge, agent))

    {:noreply, agent}
  end

  @impl true
  def handle_info({:ok, _response, key}, agent) do
    Logger.debug("Got OK: #{key}")

    {:noreply, agent}
  end

  @impl true
  def handle_info({cseq, :register}, agent) do
    msg = Requests.register(agent.account, cseq)

    Sippet.send(agent.transport, msg)

    {:noreply, Map.replace(agent, :cseq, cseq + 1)}
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
          call_id = request.headers.call_id,
          agent.name,
          request.headers.via
        )

        call = %Guppi.Call{} = Guppi.Calls.get(call_id)

        Sippet.send(
          agent.transport,
          Guppi.Requests.ack(agent.account, agent.cseq, call, to_string(sdp_offer))
        )

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
    Logger.warn("We got a REFER and shouldn't have?: #{inspect(request)}")

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

  defp create_call(call_id, from, via) do
    Guppi.Calls.create(call_id, from, via)
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

  @spec authenticate(
          Sippet.Message.t(),
          atom
          | %{:account => any, :transport => atom, optional(any) => any}
        ) :: :ok | {:error, any}
  def authenticate(challenge = %Message{headers: %{cseq: {cseq, method}}}, agent) do
    request = Requests.message(method, agent.account, cseq)

    {:ok, auth_req} =
      DigestAuth.make_request(
        request,
        challenge,
        fn _ ->
          {:ok, agent.account.sip_user, agent.account.sip_password}
        end,
        []
      )

    Sippet.send(agent.transport, Requests.via(auth_req))
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
