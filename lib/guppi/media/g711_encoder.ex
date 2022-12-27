defmodule G711u.Encoder do
  use Membrane.Filter

  require Logger

  def_input_pad(:input,
    availability: :always,
    demand_unit: :buffers,
    mode: :pull,
    caps: :any
  )

  def_output_pad(:output,
    mode: :pull,
    demand_unit: :buffers,
    caps: :any
  )

  @impl true
  def handle_init(_) do
    state = %{}

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Membrane.Buffer{} = buffer, _context, state) do
    Logger.debug(G7XX.Native.expand_ulaw_buffer(buffer.payload))

    {{:ok, buffer: {:output, buffer}}, state}
  end

  def handle_buffer(<<buffer::bitstring>>) do
    output = <<>>

    handle_buffer(buffer, output)
  end

  defp handle_buffer(<<sample::size(16), in_buff::bitstring>>, out_buff)
       when is_bitstring(out_buff) do
    output = <<(out_buff <> <<G7XX.Native.linear_to_ulaw(sample)::8>>)>>

    handle_buffer(in_buff, output)
  end

  defp handle_buffer(<<>>, out_buff) when is_bitstring(out_buff) do
    out_buff
  end
end
