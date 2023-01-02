defmodule Guppi.Call do
  defstruct [
    :id,
    :from,
    :to,
    :via
  ]

  def new(call_id, {from_name, from_uri, from_tag}, {to_name, to_uri, to_tag}, [{_v, transport, origin, %{"branch" => branch}} | _rest]) do
    case from_tag do
      %{} -> %{}
    end

    %__MODULE__{
      id: call_id,
      from: %{
        caller_id: from_name,
        uri: from_uri,
        tag: from_tag
      },
      to: %{
        caller_id: to_name,
        uri: to_uri,
        tag: to_tag
      },
      via: %{
        transport: transport,
        origin: origin,
        branch: branch
      }
    }
  end

end
