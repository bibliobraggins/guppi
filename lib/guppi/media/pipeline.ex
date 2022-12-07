defmodule Guppi.Media.Pipeline do
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
  def handle_init(%{port: port, address: address}) do
    children = %{
      file: %Membrane.File.Source{
        location: "./hold.wav"
      },
      parser: Membrane.WAV.Parser,
      audio_realtimer: Membrane.Realtimer,
      # Stream from file
      rtp_payloader: %Membrane.RTP.SessionBin{
        fmt_mapping: %{
          0 => {:PCMU, 8_000},
        }
      },
      udp_sink: %Membrane.UDP.Sink{
        destination_port_no: port,
        destination_address: address,
      },
    }

    # Setup the flow of the data
    links = [
      link(:file)
      |> to(:parser)
      |> via_in(Pad.ref(:input, 0))
      |> to(:rtp_payloader)
      |> via_out(Pad.ref(:rtp_output, 0), options: [payload_type: 0])
      |> to(:audio_realtimer)
      |> to(:udp_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}, playback: :playing}, %{}}
  end

end
