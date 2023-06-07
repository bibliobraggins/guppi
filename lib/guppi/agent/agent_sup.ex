defmodule Guppi.AgentSupervisor do
  use DynamicSupervisor

  require Logger

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

  def start_sippet(name) do
    spec = {
      Sippet,
      name: name
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_transport(name, opts) do
    # TODO: move to Transport Supervisor as child of this module - needs to dynamically switch for NAPTR to work.
    transport_mod =
      case opts.outbound_proxy.scheme do
        :tls ->
          Guppi.TlsTransport
        :tcp ->
            IO.puts("falling back to UDP, no TCP handler is available now")
          Guppi.UdpTransport
        :udp ->
          Guppi.UdpTransport
      end

    spec = {
      transport_mod,
      name: name, address: opts.ip, port: opts.port, proxy: opts.outbound_proxy
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

  def start_agent(account, transport) do
    spec = {
      Guppi.Agent,
      account: account, transport: transport
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
