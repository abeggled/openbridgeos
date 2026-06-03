# Security Model

Open Bridge OS should inherit the security posture of Open Bridge Server and
extend it to the appliance.

The core security principle is simple: expose little, generate secrets on the
device, persist data predictably, and make risky actions visible.

## Baseline Principles

- No default production secrets.
- First boot must generate per-device secrets.
- Default passwords must be changed or disabled during onboarding.
- Services should bind only to required interfaces.
- SSH should be disabled by default or require explicit enablement.
- App data and secrets must be backed up intentionally.
- Logs should be useful without leaking credentials.
- Updates should be verifiable and reversible where practical.

## First Boot Requirements

On first boot, obos should:

- generate `OBS_SECURITY__JWT_SECRET`
- generate the internal MQTT service password
- create an appliance identifier
- set hostname if configured by image metadata or first setup
- set timezone
- write app environment files with restrictive permissions
- mark first boot as complete

Target permissions:

```text
/etc/obos/                  root:root 0750
/etc/obos/apps/*.env        root:root 0600
/srv/obos/                  root:root 0750
```

## Network Exposure

Default external exposure should be minimal.

Initial allowed services:

- Open Bridge Server HTTP UI/API on `8080/tcp`
- obos administration UI once implemented

MQTT ports should be explicit configuration choices:

- `1883/tcp` MQTT
- `9001/tcp` MQTT over WebSocket

## Container Runtime

The first version uses Docker Compose because it matches the upstream Open
Bridge Server deployment. Hardening should include:

- pinned image tags or digests once release images are available
- least-needed published ports
- explicit restart policy
- persistent volumes below `/srv/obos`
- health checks for both Open Bridge Server and Mosquitto
- no arbitrary Compose editing through the web UI

## Backup and Restore

Backups should include:

- Open Bridge Server data
- Mosquitto persistent data
- obos app environment files
- obos appliance metadata needed for restore

Backups should not include:

- transient container layers
- package caches
- logs by default, unless selected

Backup export should warn when secrets are included.

## Open Questions

- Should SSH be disabled entirely on the default image, or enabled only during
  first setup with a generated password?
- Should the first public release use plain HTTP on trusted LAN only, or ship
  with local TLS via a generated certificate?
- Should MQTT be LAN-exposed by default, or internal-only until enabled?
- Should obos use full disk encryption on x86_64 installations, and what is
  the equivalent story for Raspberry Pi unattended boot?
