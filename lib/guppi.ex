defmodule Guppi do
  require Logger

  @moduledoc """
    The Guppi Application module
  """

  def start, do: start_link(nil)

  def start_link(_) do
    Registry.start_link(keys: :unique, name: Guppi.Registry)

    children = init_accounts()

    Supervisor.start_link(children, strategy: :one_for_all, name: Guppi)
  end

  def stop do
    Supervisor.stop(__MODULE__, :normal)
  end

  defp init_accounts() do
    children =
      Enum.into(
        Guppi.Account.read_config!(),
        [],
        fn account ->
          Supervisor.child_spec({Guppi.Agent, account},
            id: {Integer.to_string(account.uri.port), account.uri.userinfo}
          )
        end
      )

    [Guppi.Calls | children]
  end

  def restart do
    stop()
    Process.sleep(5)
    start()
  end

  def register(port, name) do
    Registry.register(Guppi.Registry, port, name)
  end

  def count, do: Registry.count(Guppi.Registry)
end
