defmodule Guppi.TX_FIFO do

  require Logger

  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    %{address: address, port: port} = opts

    children = %{
      # Stream from file
      audio_src: %Membrane.PortAudio.Source{},
      #encoder: G711.Encoder,
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{
          0   => {:g711, 8_000},
        }
      },
      realtimer: Membrane.Realtimer,
      udp_sink: %Membrane.UDP.Sink{
        destination_address: address,
        destination_port_no: port,
        local_address: Guppi.Helpers.local_ip()
      },
      fake: Membrane.Fake.Sink.Buffers
    }

    ssrc = Enum.random(0..131_070)

    # Setup the flow of the data
    links = [
      link(:audio_src)
      #|> to(:encoder)
      |> via_in(Pad.ref(:rtp_input, ssrc))
      |> to(:rtp)
      |> via_out(Pad.ref(:rtp_output, ssrc))
      |> to(:realtimer)
      |> to(:fake)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}, playback: :playing}, %{}}
  end

end
