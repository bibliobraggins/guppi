defmodule Agent.HandlerSupervisor do
  use DynamicSupervisor

  def start_link(agent) do
    DynamicSupervisor.start_link(__MODULE__, agent, name: agent.__MODULE__)
  end

  @impl true
  def init(agent) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [agent]
    )
  end
end
