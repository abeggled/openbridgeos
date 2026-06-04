# 0003: MQTT External Access Is Explicit Opt-In

## Status

Accepted. Initial `obosctl` enable/disable workflow is implemented; web UI and
source-network restrictions are still open.

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

Administrators may enable LAN MQTT access with:

```sh
sudo obosctl mqtt-enable-lan
```

They may restore the default closed posture with:

```sh
sudo obosctl mqtt-disable-lan
```

The workflow:

- shows current bind addresses with `sudo obosctl mqtt-status`
- keeps existing MQTT authentication enabled
- updates the app environment file instead of hand-editing Compose
- updates the managed nftables MQTT block
- restarts the firewall
- restarts the managed Open Bridge Server stack
- remains visible to CI security default checks

## Consequences

- Security tests treat external MQTT as closed for the default baseline.
- The CLI can support deployments that need LAN MQTT without making it the
  default.
- Documentation must say "disabled by default" rather than "never external".
- Public images can still support LAN MQTT without making it the default.

## Open Questions

- Should MQTT WebSocket exposure be controlled independently from plain MQTT?
- Should obos support source-network restrictions, e.g. only a specific LAN
  subnet?
- Should the UI require a confirmation step that displays the current MQTT user
  model before opening the firewall?
- Should the security baseline audit add a separate admin-enabled MQTT mode?
