# Guppi

**TODO: Add description**

Guppi is intended as an RFC 3261 && 3263 compliant "phone".

example configuration:
```
{
  "accounts": 
  [
    {
      "register": true,
      "codecs": "pcmu",
      "transport": "udp",
      "uri":"sip:username@0.0.0.0:5060",
      "sip_user":"username",
      "sip_password":"**secret**",
      "realm":"sbcrtp.b2.alianza.com",
      "sdp": {
        "direction":"recvonly",
        "rtp_range":[20000, 40000],
        "codecs": {
          "g711u":"0:PCMU:8000:1",
          "g711a":"8:PCMA:8000:1",
          "L16_8":"117:L16.8:8000:1",
          "rfc2833":"127:telephone-event:8000:1"
        }
      },
      "outbound_proxy":{
        "dns":"A",
        "host":"sbcrtp.b2.sac.alianza.com",
        "port":5065
      }
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

