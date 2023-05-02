# Guppi

Guppi is intended as an RFC 3261/3263 compliant "phone".

This project is a WIP, right now focus is on building out and abstracting SIP behavior.

Features Planned: 
- SIP call handling (wip)
- codecs: G711, OPUS | (wip)
- rfc3263 call server location (wip)
- dtmf rfc2833/4733 (not started)
- ATA device support via Nerves ( being considered )

example configuration:
```
{
  "accounts": 
  [
    {
      "register": true,
      "codecs": "pcmu",
      "transport": "udp",
      "uri":"sip:username@0.0.0.0",
      "sip_user":"username",
      "sip_password":"**secret**",
      "ip": "0.0.0.0",
      "local_port": "5060"
      "realm":"sip_provider.com",
      "outbound_proxy":{
        "dns":"A",
        "host":"proxy.sip_provider.com",
        "port":5060
      }
      "sdp": {
        "direction":"sendrecv",
        "rtp_range":[20000, 40000],
        "codecs": {
          "g711u":"0:PCMU:8000:1",
          "g711a":"8:PCMA:8000:1",
          "rfc2833":"127:telephone-event:8000:1"
        }
      },
    }
  ]
}
```
use 0.0.0.0 when you do not care what socket to listen on.

Each Account is spawned in a Guppi.Agent, and is supervised by Guppi itself.

```
iex(1)> Registry.lookup(Guppi.Registry, local_port)
{#PID<XXX>, :uri}
```

To start Guppi, Start it manually via your supervision tree, or add it to your mix applications to start it up automatically.

## Installation

# TODO: Determine hosting solutions when a viable 0.1.0 can be released.

