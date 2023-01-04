defmodule Guppi.Media.RxPipeline do
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

  alias Membrane.{Opus, RTP, UDP}

  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    spec = %ParentSpec{
      children: [
        audio_src: %UDP.Source{
          local_address: Guppi.Helpers.local_ip(),
          local_port_no: 20000
        },
        rtp: %RTP.SessionBin{
          srtp_policies: [],
          fmt_mapping: %{
            121 => {:OPUS, 48_000}
          }
        }
      ],
      links: [
        link(:audio_src) |> via_in(:rtp_input) |> to(:rtp)
      ]
    }

    {{:ok, spec: spec, playback: :playing}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 121, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :audio, ssrc)
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

  @impl true
  def handle_notification({:connection_info, _r_addr, _port}, :audio_src, _ctx, state) do
    Logger.info("Audio UDP source connected.")

    {:ok, state}
  end

  defp handle_stream(%{audio: audio_ssrc}) do
    spec = %ParentSpec{
      children: %{
        audio_decoder: Opus.Decoder,
        audio_player: Membrane.PortAudio.Sink
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, audio_ssrc),
          options: [depayloader: RTP.Opus.Depayloader]
        )
        |> to(:audio_decoder)
        |> to(:audio_player)
      ],
      stream_sync: :sinks
    }

    [spec: spec]
  end
end
