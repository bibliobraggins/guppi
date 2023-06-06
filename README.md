# Guppi

Guppi is intended as an RFC 3261/3263 compliant "phone".

This project is a WIP, right now focus is on building out and abstracting SIP behavior.

Current Status:
  - User Registration
  - Basic Call handling (WIP, no audio as of yet)
  - UDP transport (looking to implement TCP and TLS via TCP next)
  - NAPTR, SRV, or A record DNS support

example configuration:
```
{
  "accounts": 
  [
    {
      "register": true,
      "display_name":"4600",
      "uri":"sip:user@sip_provisder.com",
      "sip_user":"user",
      "sip_password":"**password**",
      "ip": "0.0.0.0",
      "user_agent": "_my_user_agent_string",
      "transport": (_one of the transport ports defined below_),
      "max_forwards":70,
      "resync_timer":3600,
      "registration_timer":3600,
      "subscribe_timer":3600
    }
  ],
  "transports": [
    {
      "ip": "0.0.0.0",
      "port":port_number,
      "outbound_proxy":{
        "type":"NAPTR",
        "domain":"my_domain"
      }
    }
  ]
}
```
Use ip: 0.0.0.0 when you do not care what address/interface to listen on.

To start Guppi, Start it manually via your supervision tree, or add it to your mix applications to start it up automatically.

## Installation

# TODO

