defmodule Guppi do
  require Logger

  @moduledoc """
    The main Guppi interface module.
  """

  def start, do: start_link(nil)

  def start_link(_) do
    children = init_config()

    Supervisor.start_link(children, strategy: :one_for_all, name: Guppi)
  end

  def stop, do: stop(:normal)

  def stop(:normal) do
    Supervisor.stop(__MODULE__, :normal)
  end

  defp init_config() do
    config = Guppi.Config.read_config!()

    agents =
      Enum.into(
        config.accounts,
        [],
        fn account ->
          Supervisor.child_spec({Guppi.Agent, account},
            id: String.to_atom(account.uri.userinfo),
            restart: :transient
          )
        end
      )

    sippets =
      Enum.into(
        config.transports,
        [],
        fn transport ->
          sip_stack(transport)
        end
      )


    transports =
      Enum.into(
        config.transports,
        [],
        fn transport ->
          setup_transport(transport)
        end
      )


    [Guppi.Calls, Guppi.AgentRegistry, transports, agents]
  end

  def restart do
    stop(:normal)
    Process.sleep(5)
    start()
  end

  def sip_stack(transport) do
    name = Integer.to_string(transport.port) |> String.to_atom()

    Supervisor.child_spec({Sippet, name: name}, [])
  end

  def setup_transport(transport) do
    name = Integer.to_string(transport.port) |> String.to_atom()
    Supervisor.child_spec(
      {
        Guppi.Transport,
        name: name,
        address: transport.ip,
        port: transport.port,
        proxy: transport.outbound_proxy
      },
      []
    )
  end

end
