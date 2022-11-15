defmodule Guppi do
  use Application
  require Logger

  @moduledoc """
    The Guppi Application module
  """

  def start, do: start [], []

  def start(_type,_args) do
    Registry.start_link(keys: :unique, name: Guppi.Registry)

    start_link([], [])
  end

  def start_link(_type, _args) do
    children = Enum.into(
        Guppi.Account.read_config!(),
        [],
        fn account ->
          Supervisor.child_spec({Guppi.Agent, account},
            id: {Integer.to_string(account.uri.port), account.uri.userinfo}
          )
        end
      )

    Supervisor.start_link(children, strategy: :one_for_all, name: Guppi)
  end

  def stop do
    Supervisor.stop(__MODULE__, :normal)
  end

  def restart do
    stop()
    Process.sleep(5)
    start()
  end

  def register(account) do
    Registry.register(Guppi.Registry, account.uri.port, String.to_atom(account.id))
  end

  def count, do: Registry.count(Guppi.Registry)

end
