defmodule Guppi do
  require Logger

  @moduledoc """
    The main Guppi interface module.
  """

  def start, do: start_link(nil)

  def start_link(_) do
    Registry.start_link(keys: :unique, name: Guppi.Registry)

    children = init_accounts()

    Supervisor.start_link(children, strategy: :one_for_all, name: Guppi)
  end

  def stop, do: stop(:normal)

  def stop(:normal) do
    Supervisor.stop(__MODULE__, :normal)
  end

  defp init_accounts() do
    children =
      Enum.into(
        Guppi.Account.read_config!(),
        [],
        fn account ->
          Supervisor.child_spec({Guppi.Agent, account},
            id: account.uri.userinfo,
            restart: :transient
          )
        end
      )

    [Guppi.Calls | children]
  end

  def register(port, name) do
    Registry.register(Guppi.Registry, port, name)
  end

  def count, do: Registry.count(Guppi.Registry)

  def restart do
    stop(:normal)
    Process.sleep(5)
    start()
  end
end
