defmodule Guppi.Agent do
  use GenServer

  require Logger

  alias Sippet.Message, as: Message

  @moduledoc """

    :init ->
      :register
               \
            401||407 --> :auth
                        /     \

  """

  def start_link(account) do
    agent_name = String.to_atom(account.uri.authority)

    {:ok, sippet} = Sippet.start_link(name: agent_name)

    {:ok, _transport_pid} =
      case account.transport do
        "udp" ->
          Guppi.Transports.UDP.start_link(
            name: agent_name,
            address: Guppi.Helpers.local_ip!(),
            port: account.uri.port
          )
      end

    Sippet.register_core(agent_name, Guppi.Core)

    GenServer.start_link(
      __MODULE__,
      %{
        account:    account,
        state:      :init,
        sippet:     sippet,
        transport:  agent_name,
        transactions: [],
      },
      name: account.uri.port |> to_charlist() |> List.to_atom()
    )
  end

  @impl true
  def init(agent) do
    Registry.start_link(keys: :duplicate, name: agent.transport)

    Logger.debug("Started #{inspect(agent.transport)}")

    {:ok, Map.replace(agent, :state, :idle)}
  end

  @impl true
  def handle_cast({:invite, request, server_key}, agent) do
    Logger.debug("Received request: #{inspect(request.start_line)}")

    response = Message.to_response(request, 200)

    Sippet.send(agent.transport, response)

    receive do
      {:on_response, _, response} ->
        Logger.debug("#{inspect(response)}")
    end

    {
      :noreply,
      %{
        account: agent.account,
        transport: agent.transport,
        sippet: agent.sippet,
        transactions: [ server_key | agent.transactions ],
      }
    }
  end

  @impl true
  def handle_call({:refer, _request, _key}, _caller, agent) do
    Logger.warn("Unimplemented SIP method Warning: #{inspect(agent.transport)} received a REFER")
    {:reply, :not_implemented, agent}
  end

  @impl true
  def handle_call({:options, _request, _key}, _caller, agent) do
    {:reply, :not_implemented, agent}
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
  def handle_call(:staagents, _caller, agent) do
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

end
