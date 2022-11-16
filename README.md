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
        "rtp_range": [20000,40000],
        "transport": "udp",
        "uri":"sip:userinfo@host:port"
      },
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

