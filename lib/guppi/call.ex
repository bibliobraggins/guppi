defmodule Guppi.Call do
  @moduledoc """
    This module defines the datastructure for call handling.

    A Call is a Struct with a particular primary id that references
    a GenServer that can handle media pipeline events as they come in
    and adjust media settings accordingly.

    All media selection, ie which audio card to use, is handled in Guppi.Agent.Media,
    based on the input Account data
  """

  @enforce_keys [
    :id,
    :agent,
    :peer_data
  ]

  defstruct @enforce_keys

  def new_call(call_id, name, [{_v, _transport, _origin, %{"branch" => _branch}} | _rest] = peer_data) do

    %__MODULE__{
      id: call_id,
      agent: name,
      peer_data: peer_data
    }
  end
end
