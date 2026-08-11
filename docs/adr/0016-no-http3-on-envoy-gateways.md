# No HTTP/3 on the Envoy gateways

**Status:** accepted
**Date:** 2026-08-10

`http3: {}` is removed from the `envoy` ClientTrafficPolicy. Both gateways serve HTTP/1.1 and HTTP/2 only. `proxyProtocol` stays, because towonel needs it.

## Why

towonel runs in passthrough mode. Its agent prepends a PROXY protocol v2 header to every connection so the origin can recover the real client IP, and [its README](https://codeberg.org/towonel/towonel#passthrough-behind-envoy-envoy-gateway) requires `proxyProtocol: optional: true` on a `ClientTrafficPolicy` or Envoy rejects the connection. Measured on `envoy-external`: `proxy_proto.versions.v2.found: 31057`. On `envoy-internal`: `0`.

Envoy cannot apply PROXY protocol to a QUIC/UDP listener. `proxy_protocol` is registered as a TCP listener filter only. [envoyproxy/envoy#36881](https://github.com/envoyproxy/envoy/issues/36881) asked for UDP support and was closed **not_planned** on 2024-12-06; a maintainer replied that it would need "a custom extension in contrib which someone... would have to write", and that it is unclear whether listener filters work for QUIC at all. No Envoy version supports this.

Setting both together therefore produces an invalid QUIC listener. Envoy rejects it and keeps the last configuration that applied:

```
network/envoy-internal/https        last_updated 2026-08-10  (current)
network/envoy-internal/https-quic   last_updated 2026-08-06  (frozen)
listener_manager.lds.update_rejected: 90
DETAILS: Didn't find a registered implementation for 'envoy.filters.listener.proxy_protocol'
```

This failure is silent. It was found only by reading listener state directly. The `SecurityPolicy` for `guacamole`, created after the freeze, was present on the TCP listener and absent from the UDP listener — so forward auth did not run for HTTP/3 requests. Firefox prefers HTTP/3, which made Guacamole show its own login form until a hard refresh moved the request to HTTP/2.

## Options considered

| Option                                                                   | Change                 | HTTP/3              | Real client IP                | Notes                                                                                      |
| ------------------------------------------------------------------------ | ---------------------- | ------------------- | ----------------------------- | ------------------------------------------------------------------------------------------ |
| **Remove `http3`** (chosen)                                              | delete one line        | lost, both gateways | kept                          | One policy. No UDP listener, so none can go stale.                                         |
| Remove `proxyProtocol`, set `proxy_protocol: "none"` per towonel service | two files, two systems | kept                | **lost for external traffic** | Matches drag0n141's shape. External requests would show the agent IP.                      |
| Two ClientTrafficPolicies, split by gateway                              | new resource           | internal only       | kept                          | Asymmetric config. Re-arms the same fault if a forward-auth app moves to `envoy-external`. |
| Keep both settings                                                       | none                   | nominal only        | kept                          | Rejected. Leaves the UDP listener permanently frozen.                                      |

## Consequences

- HTTP/3 is gone from both gateways. It was 430 connections on `envoy-internal` and 2,033 on `envoy-external`, against 6,939 and 52,474 on HTTP/1.1. HTTP/3 is a transport optimisation; no application requires it. WebSockets do not use HTTP/3 — browsers use HTTP/1.1 `Upgrade` or RFC 8441 over HTTP/2 — so Guacamole's tunnel, Home Assistant and PairDrop are unaffected.
- Only one listener per gateway now receives configuration, so a new `SecurityPolicy` cannot reach some listeners and miss others.
- `proxyProtocol` must not be re-enabled alongside `http3`. Adding `http3` back reintroduces this fault.
- Reference repos ([bjw-s-labs](https://github.com/bjw-s-labs/home-ops/blob/main/kubernetes/apps/network/envoy-gateway/gateway/envoy.yaml), [drag0n141](https://github.com/drag0n141/home-ops/blob/master/kubernetes/apps/networking/envoy-gateway/config/envoy.yaml)) set both `http3` and `proxyProtocol` in one policy. That configuration is not evidence the combination works — the failure produces no error at the application layer.
- The Envoy image version is not a factor. Envoy Gateway v1.8.3 defaults to `envoy:distroless-v1.38.3`; the reference repos pin `envoy:v1.39.0`. Neither supports PROXY protocol on QUIC.
