defmodule Membrane.RTP.Opus.Payloader do
  @moduledoc """
  Parses RTP payloads into parseable Opus packets.

  Based on [RFC 7587](https://tools.ietf.org/html/rfc7587).
  """

  use Membrane.Filter

  alias Membrane.{Opus, RTP, RemoteStream}

  def_input_pad :input,
    caps: [
      {Opus, self_delimiting?: false},
      {RemoteStream, type: :packetized, content_format: one_of([nil, Opus])}
    ],
    demand_unit: :buffers

  def_output_pad :output, caps: RTP

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {{:ok, caps: {:output, %RTP{}}}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, buffer: {:output, buffer}}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end
end
