defmodule Guppi do
  require Logger

  alias Guppi.AgentSupervisor, as: AgentSupervisor
  alias Guppi.AgentRegistry, as: AgentRegistry

  @moduledoc """
    The main Guppi interface module.
  """

  def start, do: start_link(nil)

  def start_link(_) do
    children = [
      Guppi.Calls,
      {Registry, keys: :unique, name: AgentRegistry},
      AgentSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_all, name: Guppi)

    Process.sleep(500)

    init_config()
  end

  def stop, do: stop(:normal)

  def stop(:normal) do
    Supervisor.stop(__MODULE__, :normal)
  end

  defp init_config() do
    config = Guppi.Config.read_config!()

    Enum.each(
      config.transports,
      fn transport ->
        sip_stack(transport.port)
        |> AgentSupervisor.start_sippet()
      end
    )

    Enum.each(
      config.transports,
      fn transport ->
        sip_stack(transport.port)
        |> AgentSupervisor.start_transport(transport)
      end
    )

    Enum.each(
      config.transports,
      fn transport ->
        sip_stack(transport.port)
        |> AgentSupervisor.start_core()
      end
    )

    Enum.each(
      config.accounts,
      fn account ->
        AgentSupervisor.start_agent(account, sip_stack(account.transport))
      end
    )
  end

  def restart do
    stop(:normal)
    Process.sleep(5)
    start()
  end

  def sip_stack(port) when is_integer(port) and port > 0 and port < 65536 do
    Integer.to_string(port) |> String.to_atom()
  end
end
