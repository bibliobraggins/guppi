defmodule Guppi.Media do
  def sdp(account) do
    %ExSDP{
      version: 0,
      origin: [
        network_type: "IN",
        address: :inet_parse.address(account.uri.host),
        session_id: Enum.random(0..131_070),
        session_version: 0
      ]
    }
  end

  def fake_sdp() do
    %ExSDP{
      version: 0,
      session_name: "Guppi_#{Enum.random(0..65_535)}",
      origin: %ExSDP.Origin{
        username: "-",
        network_type: "IN",
        session_id: Enum.random(0..65_535),
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
              payload_type: 0,
              encoding: "G711",
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

  def l16_8() do
    %ExSDP.Attribute.RTPMapping{
      payload_type: 117,
      encoding: "L16.8",
      clock_rate: 8000,
      params: 1
    }
  end
end
