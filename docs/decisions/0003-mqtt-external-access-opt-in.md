# 0003: MQTT External Access Is Explicit Opt-In

## Status

Accepted.

## Context

Open Bridge Server includes an internal Mosquitto broker. Many installations can
keep MQTT internal to the appliance, but some real deployments need direct MQTT
access from other LAN systems, panels, gateways, or automation tools.

Exposing MQTT by default would increase the appliance attack surface. For a
security-focused appliance, MQTT should start closed externally and become
available only after an administrator deliberately enables it.

## Decision

MQTT external access is disabled by default and must be explicit opt-in.

The default state is:

- MQTT plain bound to `127.0.0.1:1883`
- MQTT WebSocket bound to `127.0.0.1:9001`
- no nftables allow rule for TCP `1883`
- no nftables allow rule for TCP `9001`

A future `obosctl` and web UI workflow should allow administrators to enable LAN
MQTT access intentionally. That workflow must:

- show which ports will be exposed
- require existing MQTT authentication to remain enabled
- update the app environment file instead of hand-editing Compose
- update the firewall profile
- restart the managed Open Bridge Server stack
- record the resulting exposure in the security baseline audit

## Consequences

- Security tests should treat external MQTT as closed for the default baseline.
- The baseline audit should eventually distinguish default-closed and
  admin-enabled MQTT states.
- Documentation must say "disabled by default" rather than "never external".
- Public images can still support LAN MQTT without making it the default.

## Open Questions

- Should MQTT WebSocket exposure be controlled independently from plain MQTT?
- Should obos support source-network restrictions, e.g. only a specific LAN
  subnet?
- Should the UI require a confirmation step that displays the current MQTT user
  model before opening the firewall?
