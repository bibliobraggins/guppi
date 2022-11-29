defmodule Guppi.Media do

  def sdp(%Guppi.Account{} = account) do
    ExSDP.new([
      version: 0,

      origin: [
        network_type: "IN",
        address: :inet_parse.address(account.uri.host),
        session_id: Enum.random(0..131_070),
        session_version: 0,
      ],
      attributes: [String.to_atom(account.sdp.direction)],
      connection_data: [
        address: :inet_parse.address(account.uri.host),
        ttl: account.sdp.ttl
      ]
    ])
  end

  def fake_sdp() do
    %ExSDP{
      version: 0,
      session_name: "Polycom IP Phone",
      origin: %ExSDP.Origin{
        username: "-",
        network_type: "IN",
        session_id: 1669678468,
        session_version: 1669678468,
        address: {192, 168, 3, 105}
      },
      timing: %ExSDP.Timing{
        start_time: 0,
        stop_time: 0
      },
      time_zones_adjustments: nil,
      connection_data: %ExSDP.ConnectionData{address: {192, 168, 3, 105}, network_type: "IN"},
      attributes: [:sendrecv],
      bandwidth: [],
      media: [
        %ExSDP.Media{
          type: :audio,
          port: 2246,
          protocol: "RTP/AVP",
          fmt: [117, 0, 127],
          port_count: 1,
          connection_data: %ExSDP.ConnectionData{address: {192, 168, 3, 105}, address_count: nil, ttl: nil, network_type: "IN"},
          bandwidth: [],
          attributes: [%ExSDP.Attribute.RTPMapping{
            payload_type: 117,
            encoding: "L16",
            clock_rate: 8000,
            params: 1
          },
          %ExSDP.Attribute.RTPMapping{
            payload_type: 0,
            encoding: "PCMU",
            clock_rate: 8000,
            params: 1
          },
          %ExSDP.Attribute.RTPMapping{
            payload_type: 127,
            encoding: "telephone-event",
            clock_rate: 8000,
            params: 1
          }
        ]
      }
    ],
    time_repeats: []
  }
  end
end
