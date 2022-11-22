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
          :init
      end

    # run the agent GenServer
    GenServer.start_link(
      __MODULE__,
      %{
        account: account,
        state: init_state,
        sippet: sippet,
        transport: transport_name,
        cseq: 0,
      },
      name: account.name
    )
  end

  @impl true
  def init(agent) do
    # we immedaitely register the "valid agent" to Guppi.Registry
    case Guppi.register(agent.account.uri.port, agent.account.uri.userinfo) do
      {:ok, _} -> :ok
      error -> Logger.warn(inspect(error))
    end

    # on initialization, should we immediately register or are we clear to transmit?
    case agent.state do
      :register ->
        #GenServer.cast(self(), :register)
        Guppi.Register.start_link(agent)
        {:ok, agent}
      _ ->
        {:ok, agent}
    end
  end

  @impl true
  def handle_info({:authenticate, %Message{start_line: %StatusLine{}, headers: %{cseq: cseq}} = challenge}, agent) do

    request = case cseq do
      {_, :register} -> Guppi.Register.make_register(agent)
      _ -> raise RuntimeError, "#{agent.account.uri.userinfo} was challenged on a method we can't make yet"
    end

    {:ok, auth_request} =
      DigestAuth.make_request(
        request,
        challenge,
        fn _ -> {:ok, agent.account.sip_user, agent.account.sip_password} end,
        []
    )
    auth_request =
      auth_request
      |> Message.update_header(:cseq, fn {seq, method} ->
        {seq + 1, method}
      end)
      |> Message.update_header_front(:via, fn {ver, proto, hostport, params} ->
        {ver, proto, hostport, %{params | "branch" => Message.create_branch()}}
      end)
      |> Message.update_header(:from, fn {name, uri, params} ->
        {name, uri, %{params | "tag" => Message.create_tag()}}
      end)

    case Sippet.send(agent.transport, auth_request) do
      :ok ->
        {:noreply, Map.put_new(agent, :cseq, agent.cseq + 1)}
      {:error, reason} ->
        Logger.warn("could not send auth request: #{reason}")
    end
  end

  @impl true
  def handle_info({:ok, _ok_response, key}, agent) do
    Logger.debug("Got OK: #{key}")

    {:noreply, agent}
  end

  @impl true
  def handle_info(:register, agent) do

    registration = Guppi.Register.make_register(agent)

    case Sippet.send(agent.transport, registration) do
      :ok -> Logger.debug("Attempting to send registration")
    end

    {:noreply, agent}
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

  @impl true
  def handle_cast({:bye, _request, _key}, agent) do
    {:noreply, :not_implemented, agent}
  end

  @impl true
  def handle_cast(:status, agent) do
    {:noreply, agent, agent}
  end

  @impl true
  def terminate(_, _) do
    Logger.critical("WHY DID MY GENSERVER STOP\nWHY DID MY GENSERVER STOP\nWHY DID MY GENSERVER STOP\nWHY DID MY GENSERVER STOP\n")
  end


end
