defmodule Guppi.Media.Pipeline do
  use Membrane.Pipeline

  alias Membrane.{PortAudio}

  @impl true
  def handle_init(_opts) do

    children = [
      pa_src: PortAudio.Source,
      pa_sink: PortAudio.Sink
    ]

    links = [
      link(:pa_src)
      |> to(:pa_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
