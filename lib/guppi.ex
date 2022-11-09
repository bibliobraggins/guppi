defmodule Guppi do
  use Application
  require Logger

  @moduledoc """
    The Guppi Application module
  """

  def start, do: start [], []

  def start(_type,_args), do: start_link([], [])

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
    Enum.each(agents(), fn name ->
      Supervisor.terminate_child(__MODULE__, name)
    end)

    Supervisor.stop(__MODULE__, :normal)
  end

  def restart do
    stop()
    Process.sleep(5)
    start()
  end

  def agents do
    Enum.into(
      Supervisor.which_children(__MODULE__),
      [],
      fn {{port, user}, _pid, _type, _module} ->
        {String.to_existing_atom(port), String.to_existing_atom(user)}
      end
    )
  end
end
