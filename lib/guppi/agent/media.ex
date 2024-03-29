defmodule Guppi.Agent.Media do
  alias Guppi.Config.Account, as: Account

  def sdp(account = %Account{}, _offer) do
    # todo: add conditions for best candidate selection, instead of static codec offering

    id = Enum.random(0..65_535)

    %ExSDP{
      version: 0,
      session_name: "Guppi_#{id}",
      origin: %ExSDP.Origin{
        username: "-",
        network_type: "IN",
        session_id: id,
        session_version: 0,
        address: account.ip
      },
      attributes: [:sendrecv],
      bandwidth: [],
      media: [
        %ExSDP.Media{
          type: :audio,
          port: 20000,
          protocol: "RTP/AVP",
          fmt: [0],
          port_count: 1,
          connection_data: %ExSDP.ConnectionData{
            address: account.ip,
            address_count: nil,
            ttl: nil,
            network_type: "IN"
          },
          attributes: [
            %ExSDP.Attribute.RTPMapping{
              payload_type: 121,
              encoding: "OPUS",
              clock_rate: 48000
            },
            %ExSDP.Attribute.RTPMapping{
              payload_type: 127,
              encoding: "telephone-event",
              clock_rate: 8000
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
