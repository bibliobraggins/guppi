defmodule Guppi.Media.Pipeline do
  require Logger

  @doc """
    TODO:
    - The pipeline is invalid right now, not any of its elements.
    - The way this works, the address and port for the local sink needs to be set when we start the pipeline:

      Guppi.Media.Pipeline.start_link(%{
          address: Guppi.Helpers.local_ip(),
          port:    non_negative_integer(),
          audio_device: todo!()
        }
      )

    - Need to build system for selecting and configuring which audio device it should use for streams

    - Add hook for injecting DTMF events (rfc2833/rfc4733) into the outbound RTP stream
      This will likely be best done as another source element linked to the same RTP output pad
      as the audio itself

    - rfc2833/rfc4733 internal table and respective payload definitions

    - implement MOS aggregation based on RTCP events?
  """

  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    %{endpoint_id: audio_device, l_addr: l_addr, l_port: l_port} = opts

    children = %{
      # Stream from file
      udp_source: %Membrane.UDP.Source{
        local_port_no: l_port,
        local_address: l_addr
      },
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{
          0 => {:g711, 8_000},
          127 => {:telephone_event, 8_000}
        }
      }
    }

    # Setup the flow of the data
    links = [
      link(:udp_source)
      |> via_in(Pad.ref(:rtp_input))
      |> to(:rtp)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}, playback: :playing},
     %{endpoint_id: audio_device}}
  end

  @impl true
  def handle_notification({:connection_info, _host, _port}, :udp_source, _ctx, state) do
    Logger.info("Audio UDP source connected.")
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 0, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :audio, ssrc)

    actions = handle_stream(state)

    {{:ok, actions}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 127, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :audio_src, ssrc)
    actions = handle_stream(state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_notification(
        {:new_rtp_stream, _ssrc, encoding_name, _extensions},
        :rtp,
        _ctx,
        _state
      ) do
    raise "Unsupported encoding: #{inspect(encoding_name)}"
  end

  defp handle_stream(state) do
    spec = %ParentSpec{
      children: %{
        decoder: G711u.Decoder,
        player: %Membrane.PortAudio.Sink{
          endpoint_id: state.endpoint_id
        },
        fake: Membrane.Fake.Sink.Buffers
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, audio_src: state.audio_ssrc))
        |> to(:decoder)
        |> to(:fake)
      ],
      stream_sync: :sinks
    }

    [spec: spec]
  end
end
