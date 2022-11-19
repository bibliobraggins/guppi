defmodule Guppi.Agent.Call do
  @keys [
    :direction,
    :remote_sessions,
    :local_session,
    :timestamp
  ]

  defstruct @keys

  def new(direction, remote_session, local_session) do
    %__MODULE__{
      direction: direction,
      local_session: local_session,
      remote_sessions: {remote_session}
    }
  end
end
