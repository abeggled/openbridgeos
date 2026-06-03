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
- SSH is disabled by default and must be enabled deliberately.
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

Default external exposure is minimal:

- Open Bridge Server HTTP UI/API on `8080/tcp`
- no external SSH
- no external MQTT
- obos administration UI once implemented

The host firewall uses nftables with inbound default-drop. It allows loopback,
established traffic, ICMP/IPv6 ICMP, and TCP `8080`.

MQTT remains bound to localhost by default:

```text
127.0.0.1:1883
127.0.0.1:9001
```

## Host Hardening

Provisioning applies:

- nftables firewall rules from `packaging/nftables/obos.nft`
- sysctl baseline from `packaging/sysctl/99-obos-hardening.conf`
- SSH service disablement when `ssh.service` exists

Manual remote development installs can preserve SSH temporarily with:

```sh
sudo OBOS_DISABLE_SSH=0 scripts/bootstrap/provision-debian.sh
```

See [hardening.md](hardening.md).

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

- Should the first public release use plain HTTP on trusted LAN only, or ship
  with local TLS via a generated certificate?
- Should obos use full disk encryption on x86_64 installations, and what is
  the equivalent story for Raspberry Pi unattended boot?
- Should Docker be replaced or constrained further once the first appliance
  image has been validated?
