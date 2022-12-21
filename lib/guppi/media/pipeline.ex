defmodule Guppi.Media.Pipeline do

  require Logger

  @doc """
    TODO:
      implement Audio Media & RTP sources & sinks -
      take in parameters from SDP media, build session specifics and set up streams

    TODO:
      we have to use PCMU. there's just no way around it. Opus is on the table too, but
      the critical problem is converting the s16le samples to pcm_mulaw without breaking anything

    TODO:
      add hook for injecting DTMF events (rfc2833/rfc4733) into the outbound RTP stream
      This will likely be best done as another source element linked to the same RTP output pad
      as the audio itself

    TODO:
      rfc2833/rfc4733 internal table and respective payload definitios

    TODO:
      specify media hardware ID somewhere. maybe accounts.json
      can hold a ref to a host specific audio card ID that is hopefully pseudo consistent
      (best case scenrio is indexed mic/spkr pairs)

    TODO:
      implement MOS aggregation based on RTCP events?
  """

  use Membrane.Pipeline

  @impl true
  def handle_init(_) do

    children = %{
      # Stream from file
      udp_source: %Membrane.UDP.Source{
        local_port_no: 20000,
        local_address: Guppi.Helpers.local_ip(),
      },
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{
          0   => {:g711, 8_000},
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

    {{:ok, spec: %ParentSpec{children: children, links: links}, playback: :playing}, %{}}
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

  defp handle_stream(%{audio: audio_ssrc}) do
    spec = %ParentSpec{
      children: %{
        decoder: G711u.Decoder,
        player: %Membrane.PortAudio.Sink{},
        fake: Membrane.Fake.Sink.Buffers,
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, audio: audio_ssrc))
        |> to(:decoder)
        |> to(:fake)
      ],
      stream_sync: :sinks
    }

    [spec: spec]
  end

end
