defmodule Membrane.RTP.Opus.Depayloader do
  @moduledoc """
  Parses RTP payloads into parseable Opus packets.

  Based on [RFC 7587](https://tools.ietf.org/html/rfc7587).
  """

  use Membrane.Filter

  alias Membrane.{Opus, RTP, RemoteStream}

  def_input_pad :input, caps: RTP, demand_unit: :buffers

  def_output_pad :output, caps: {RemoteStream, type: :packetized, content_format: Opus}

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {{:ok, caps: {:output, %RemoteStream{type: :packetized, content_format: Opus}}}, state}
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
