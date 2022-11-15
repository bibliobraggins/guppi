defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  #alias Sippet.Message.StatusLine, as: StatusLine
  alias Sippet.DigestAuth, as: DigestAuth

  @moduledoc """

    :init ->
      :register
               \
            401||407 --> :auth
                        /     \

  """
  def start_link(account) do
    agent_name =  account.uri.userinfo |> String.to_atom()

    proxy =
      with true <- Map.has_key?(account, :outbound_proxy),
           true <- Map.has_key?(account.outbound_proxy, :dns) do
            case account.outbound_proxy.dns do
              "A" ->
              {account.outbound_proxy.host, account.outbound_proxy.port}
              "SRV" ->
                raise ArgumentError, "Cannot use SRV records at this time"
              _ -> nil
            end
      end

    # start sippet instance based on sip user data
    {:ok, sippet} = Sippet.start_link(name: agent_name)

    # build a
    {:ok, _transport_pid} =
      case account.transport do
        "udp" ->
          Guppi.Transports.UDP.start_link(
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
        account:    account,
        state:      init_state,
        sippet:     sippet,
        transport:  agent_name,
        transactions: [],
        messages: [],
      }
    )
  end

  @impl true
  def init(agent) do
    # we immedaitely register the "valid agent" to Guppi.Registry
    case Guppi.register(agent.account) do
      {:ok, _} -> :ok
      error -> Logger.warn inspect error
    end
    # on initialization, should we immediately register or are we clear to transmit?
    case agent.state do
      :register ->
        {:ok, agent, {:continue, :register}}
      _ ->
        {:ok, Map.replace(agent, :state, :idle)}
    end
  end

  @impl true
  def handle_continue(:register, agent) do
    # here we just match on the register functions output.
    registration = Guppi.Register.make_register(agent)

    Sippet.send(agent.transport, registration)

    {:noreply, Map.replace(agent, :messages, List.insert_at(agent.messages, -1, registration))}
  end

  @impl true
  def handle_cast({%Message{start_line: %RequestLine{}}} = {_ack}, agent) do
    #Logger.debug("#{inspect(ack.headers)}")

    {:noreply, agent}
  end

  @impl true
  def handle_call({:response, _request, _key}, _caller, agent) do
    Logger.warn("Unimplemented SIP method Warning: #{inspect(agent.transport)} received a REFER")
    {:reply, :not_implemented, agent}
  end

  @impl true
  def handle_call({:authenticate, response, _key}, _caller, agent) do
    {:ok, new_req} = DigestAuth.make_request(List.first(agent.messages), response, fn _ -> {:ok, agent.account.sip_user, agent.account.sip_password} end, [])

    new_req =
      new_req
      |> Message.update_header(:cseq, fn {seq, method} ->
        {seq + 1, method}
      end)
      |> Message.update_header_front(:via, fn {ver, proto, hostport, params} ->
        {ver, proto, hostport, %{params | "branch" => Message.create_branch()}}
      end)
      |> Message.update_header(:from, fn {name, uri, params} ->
        {name, uri, %{params | "tag" => Message.create_tag()}}
      end)

    Sippet.send(agent.transport, new_req)
    {
      :noreply,
      Map.replace(agent, :state, :idle)
    }
  end

  @impl true
  def handle_call({:invite, request, server_key}, _caller, agent) do
    Logger.debug("Received request: #{inspect(request.start_line)}")

    response = %Message{} = Message.to_response(request, 200)
    |> Message.put_header(:content_type, "application/sdp")

    Logger.debug(inspect(response))

    {
      :reply,
      Sippet.send(agent.transport, response),
      Map.replace(agent, :transactions, [server_key | agent.transactions])
    }
  end

  @impl true
  def handle_call({:refer, _request, _key}, _caller, agent) do
    Logger.warn("Unimplemented SIP method Warning: #{inspect(agent.transport)} received a REFER")
    {:reply, :not_implemented, agent}
  end

  @impl true
  def handle_call({:options, request, _key}, _caller, agent) do
    response = Message.to_response(request, 200)
    |> Message.put_header(:content_type, "application/sdp")

    {:reply, Sippet.send(agent.transport, response), agent}
  end

  @impl true
  def handle_call({:cancel, _request, _key}, _caller, agent) do
    {:reply, :not_implemented, agent}
  end

  @impl true
  def handle_call({:bye, _request, _key}, _caller, agent) do
    {:reply, :not_implemented, agent}
  end

  @impl true
  def handle_call(:status, _caller, agent) do
    {:reply, agent, agent}
  end

  @impl true
  def handle_call(:stop, _caller, agent) do
    # TODO
    case on_call?(agent) do
      true -> {:reply, {:error, :on_call, agent.account.uri.authority}}
      false -> {:stop, :normal}
    end
  end

  # TODO
  defp on_call?(_agent), do: false || true

  def authenticate(account) do
    {username, password} =
      with {:ok, user} <- Map.fetch(account, :sip_user),
           {:ok, password} <- Map.fetch(account, :sip_password) do
            {user, password}
    end
    {:ok, username, password}
  end

end
