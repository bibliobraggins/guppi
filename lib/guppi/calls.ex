defmodule Guppi.Calls do
  use GenServer

  require Logger

  alias Guppi.Call, as: Call

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :calls)
  end

  def create(call_id, agent, peer_data) do
    GenServer.cast(:calls, {:create, {call_id, agent, peer_data}})
  end

  def get(call_id) do
    GenServer.call(:calls, {:get, call_id})
  end

  def show do
    GenServer.call(:calls, {:show})
  end

  def delete(key) do
    GenServer.cast(:calls, {:delete, key})
  end

  def stop do
    GenServer.stop(:calls)
  end

  ###

  @impl true
  def init(args) do
    {:ok, Enum.into(args, %{})}
  end

  @impl true
  def handle_cast({:create, {call_id, agent, peer_data}}, state) do
    {:noreply, Map.put(state, call_id, Call.new_call(call_id, agent, peer_data))}
  end

  @impl true
  def handle_cast({:delete, call_id}, state) do
    {:noreply, Map.delete(state, call_id)}
  end

  @impl true
  def handle_call({:get, call_id}, _from, state) do
    {:reply, state[call_id], state}
  end

  @impl true
  def handle_call({:show}, _from, state) do
    {:reply, Map.keys(state), state}
  end
end
