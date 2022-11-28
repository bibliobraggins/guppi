defmodule Guppi.Agent.Call do
  @keys [
    :type,
    :remote_sessions,
    :local_session,
    :timestamp
  ]

  defstruct @keys

  def new(direction, remote_session, local_session) do
    %__MODULE__{
      type: direction,
      local_session: local_session,
      remote_sessions: {remote_session}
    }
  end
end
