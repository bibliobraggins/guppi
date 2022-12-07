defmodule Guppi.Media do
  def sdp(%Guppi.Account{} = account) do
    description =
      ExSDP.new(
        version: 0,
        origin: [
          network_type: "IN",
          address: :inet_parse.address(account.uri.host),
          session_id: Enum.random(0..131_070),
          session_version: 0
        ],
        attributes: [String.to_atom(account.sdp.direction)],
        connection_data: [
          address: :inet_parse.address(account.uri.host)
        ]
      )

    description
  end

  def fake_sdp() do
    %ExSDP{
      version: 0,
      session_name: "Polycom IP Phone",
      origin: %ExSDP.Origin{
        username: "-",
        network_type: "IN",
        session_id: Enum.random(0..65535),
        session_version: 0,
        address: Guppi.Helpers.local_ip()
      },
      timing: %ExSDP.Timing{
        start_time: 0,
        stop_time: 0
      },
      time_zones_adjustments: nil,
      connection_data: %ExSDP.ConnectionData{
        address: Guppi.Helpers.local_ip(),
        network_type: "IN"
      },
      attributes: [:sendrecv],
      bandwidth: [],
      media: [
        %ExSDP.Media{
          type: :audio,
          port: 20000,
          protocol: "RTP/AVP",
          fmt: [10],
          port_count: 1,
          connection_data: %ExSDP.ConnectionData{
            address: Guppi.Helpers.local_ip(),
            address_count: nil,
            ttl: nil,
            network_type: "IN"
          },
          attributes: [
            %ExSDP.Attribute.RTPMapping{
              payload_type: 101,
              encoding: "OPUS",
              clock_rate: 48000,
              params: 1
            }
          ]
        }
      ],
      time_repeats: []
    }
  end
end
