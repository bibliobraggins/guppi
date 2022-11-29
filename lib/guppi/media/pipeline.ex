defmodule Guppi.Media.Pipeline do
  use Membrane.Pipeline

  alias Membrane.{PortAudio, UDP, RTP}

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

  @impl true
  def handle_init(opts) do
    spec = %ParentSpec{
      children: [
        audio_src: %UDP.Source{
          local_port_no: opts.local_port,
          local_address: opts.local_ip
        },
        rtp: %RTP.SessionBin{
          fmt_mapping: %{
            0 => {:PCMU, 8_000},
            120 => {:OPUS, 48_000}
          }
        }
        ]
      }

    children = [
      pa_src: PortAudio.Source,
      pa_sink: PortAudio.Sink
    ]

    links = [
      link(:audio_src) |> via_in(:rtp_input) |> to(:rtp)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
