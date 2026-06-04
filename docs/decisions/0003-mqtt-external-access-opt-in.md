# 0003: MQTT External Access Is Explicit Opt-In

## Status

Accepted. The `obosctl` enable/disable workflow is implemented, including
optional source-network restriction. Web UI confirmation flow is still open.

## Context

open bridge server includes an internal Mosquitto broker. Many installations can
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

They may restrict the firewall allow rules to a specific IPv4 or IPv6 source
network:

```sh
sudo obosctl mqtt-enable-lan 192.168.1.0/24
sudo obosctl mqtt-enable-lan fd00::/64
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
- can restrict nftables rules to a source CIDR when supplied
- restarts the firewall
- restarts the managed open bridge server stack
- remains visible to CI security default checks

## Consequences

- Security tests treat external MQTT as closed for the default baseline.
- The CLI can support deployments that need LAN MQTT without making it the
  default.
- Documentation must say "disabled by default" rather than "never external".
- Public images can still support LAN MQTT without making it the default.

## Open Questions

- Should MQTT WebSocket exposure be controlled independently from plain MQTT?
- Should the UI require a confirmation step that displays the current MQTT user
  model before opening the firewall?
- Should the security baseline audit add a separate admin-enabled MQTT mode?
