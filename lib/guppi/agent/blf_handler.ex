defmodule Guppi.BlfHandler do
  use GenServer

  require Logger

  def start_link(agent) do
    GenServer.start_link(__MODULE__, agent)
  end

  @impl true
  def init(agent) do
    {:ok, agent, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subcribe, agent) do
    send(agent, :subscribe)

    {:noreply, agent, {:continue, :wait}}
  end

  @impl true
  def handle_continue(:wait, agent) do
    Process.sleep(agent.account.subscription_timer * 100)

    {:noreply, agent, {:continue, :subscribe}}
  end

  def make_blf_subscribe(agent) do
    cseq =
      case Map.has_key?(agent, :cseq) do
        true ->
          agent.cseq + 1

        false ->
          1
      end

    #Guppi.Requests.subscribe(agent.account, cseq)
  end
end
