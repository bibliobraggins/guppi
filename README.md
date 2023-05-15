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
      "uri":"sip:username@sip_provider.com",
      "sip_user":"username",
      "sip_password":"**secret**",
      "transport": "5060"
      "realm":"sip_provider.com",
    }
  ],
  "transports": [
    {
      "ip": "0.0.0.0",
      "port": 5060,
      "outbound_proxy":{
        "dns":"A",
        "host":"proxy.sip_provider.com",
        "port":5060
      }
    }
  ]
}
```
Use ip: 0.0.0.0 when you do not care what address/interface to listen on.

To start Guppi, Start it manually via your supervision tree, or add it to your mix applications to start it up automatically.

