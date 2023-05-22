defmodule Guppi.AgentSupervisor do
  use DynamicSupervisor

  def start_link([]) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: []
    )
  end

  def start_agent(account, transport) do
    spec = {
      Guppi.Agent,
      account: account, transport: transport
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_sippet(name) do
    spec = {
      Sippet,
      name: name
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_transport(name, transport) do
    spec = {
      Guppi.Transport,
      name: name, address: transport.ip, port: transport.port, proxy: transport.outbound_proxy
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_core(name) do
    spec = {
      Guppi.Core,
      name: name
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
