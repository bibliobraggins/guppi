defmodule Guppi.RegistrationScheduler do
  use GenServer

  require Logger

  def start_link(agent) do
    GenServer.start_link(__MODULE__, agent)
  end

  @impl true
  def init(agent) do
    {:ok, agent, {:continue, :register}}
  end

  @impl true
  def handle_continue(:register, agent) do
    send(agent.name, :register)

    {:noreply, agent, {:continue, :wait}}
  end

  @impl true
  def handle_continue(:wait, agent) do
    Process.sleep(agent.account.registration_timer * 100)

    {:noreply, agent, {:continue, :register}}
  end

  def make_register(agent) do
    cseq =
      case Map.has_key?(agent, :cseq) do
        true ->
          agent.cseq + 1

        false ->
          1
      end

    Guppi.Requests.register(agent.account, cseq)
  end
end
