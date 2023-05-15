defmodule Guppi.AgentRegistry do
  use GenServer

  # Client API #
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :agent_registry)
  end

  def register_name(key, pid) when is_pid(pid) do
    GenServer.call(:registry, {:register_agent, key, pid})
  end

  # Server API #
  def init(nil) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register_agent, key, pid}, _from, registry) do
    case Map.get(registry, key, nil) do
      nil ->
        Process.monitor(pid)
        registry = Map.put(registry, key, pid)
        {:reply, :yes, registry}

      _ -> {:reply, :no, registry}
    end
  end

end
