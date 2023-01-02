defmodule Guppi.Calls do
  use GenServer

  require Logger

  alias Guppi.Call, as: Call

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :calls)
  end

  def create(call_id, from, to, via) do
    GenServer.cast(:calls, {:create, {call_id, from, to, via}})
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

  def init(args) do
    {:ok, Enum.into(args, %{})}
  end

  def handle_cast({:create, {call_id, from, to, via}}, state) do
    {:noreply, Map.put(state, call_id, Call.new(call_id, from, to, via))}
  end

  def handle_cast({:delete, call_id}, state) do
    {:noreply, Map.delete(state, call_id)}
  end

  def handle_call({:get, call_id}, _from, state) do
    {:reply, state[call_id], state}
  end

  def handle_call({:show}, _from, state) do
    {:reply, Map.keys(state), state}
  end
end
