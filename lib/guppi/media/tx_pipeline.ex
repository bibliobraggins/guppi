defmodule Guppi.Media.TxPipeline do
  require Logger

  use Membrane.Pipeline

  @impl true
  def handle_init(sdp = %ExSDP{}) do
    audio_ssrc = 10_101_010

    children = %{
      # Stream from file
      audio_src: %Membrane.PortAudio.Source{},
      encoder: Membrane.Opus.Encoder,
      audio_parser: %Membrane.Opus.Parser{input_delimitted?: true, delimitation: :undelimit},
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{
          121 => {Opus, 48_000}
        }
      },
      audio_realtimer: Membrane.Realtimer,
      # realtimer: Membrane.Realtimer,
      # udp_sink: %Membrane.UDP.Sink{
      #  destination_address: address,
      #  destination_port_no: port,
      #  local_address: Guppi.Helpers.local_ip()
      # },
      udp_sink: %Membrane.UDP.Sink{
        destination_port_no: sdp.connection_data.address,
        destination_address: sdp.media[0].port
      }
    }

    # ssrc = Enum.random(0..131_070)

    # Setup the flow of the data
    links = [
      link(:audio_src)
      |> to(:audio_parser)
      |> via_in(Pad.ref(:input, audio_ssrc), options: [payloader: RTP.Opus.Payloader])
      |> to(:rtp)
      |> via_out(Pad.ref(:rtp_output, audio_ssrc), options: [encoding: :OPUS])
      |> to(:audio_realtimer)
      |> to(:audio_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}, playback: :playing}, %{}}
  end
end
