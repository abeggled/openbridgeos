# Security Model

Open Bridge OS should inherit the security posture of Open Bridge Server and
extend it to the appliance.

The core security principle is simple: expose little, generate secrets on the
appliance instance, persist data predictably, and make risky actions visible.

## Baseline Principles

- No default production secrets.
- First boot must generate per-appliance-instance secrets.
- Default passwords must be changed or disabled during onboarding.
- Services should bind only to required interfaces.
- SSH is disabled by default and must be enabled deliberately.
- App data and secrets must be backed up intentionally.
- TLS trust must be appliance-instance-specific, verifiable, and replaceable.
- Logs should be useful without leaking credentials.
- Updates should be verifiable and reversible where practical.

## First Boot Requirements

On first boot, obos should:

- generate `OBS_SECURITY__JWT_SECRET`
- generate the internal MQTT service password
- generate `/etc/obos/appliance-id` as a stable UUID
- generate per-appliance-instance TLS trust material
- export public trust information without private keys
- set hostname if configured by image metadata or first setup
- set timezone
- write app environment files with restrictive permissions
- mark first boot as complete

See [0004: Use a Per-Appliance-Instance Local CA for TLS Trust Onboarding](decisions/0004-local-ca-trust-onboarding.md)
and [tls-trust.md](tls-trust.md).

Target permissions:

```text
/etc/obos/                  root:root 0750
/etc/obos/appliance-id      root:root 0644
/etc/obos/apps/*.env        root:root 0600
/etc/obos/tls/              root:root 0700
/srv/obos/                  root:root 0750
/srv/obos/state/            root:root 0750
/srv/obos/state/last-update root:root 0640
```

## Network Exposure

Default external exposure is minimal:

- HTTPS reverse proxy on `443/tcp`
- no external direct Open Bridge Server HTTP
- no external SSH
- MQTT external access disabled by default
- obos administration UI once implemented, behind the same TLS boundary

Open Bridge Server binds to localhost behind nginx:

```text
127.0.0.1:8080
```

The host firewall uses nftables with inbound default-drop. It allows loopback,
established traffic, ICMP/IPv6 ICMP, DHCP renewals, and TCP `443`.

MQTT remains bound to localhost by default:

```text
127.0.0.1:1883
127.0.0.1:9001
```

Administrators can enable LAN MQTT access explicitly with:

```sh
sudo obosctl mqtt-enable-lan
```

That action exposes TCP `1883` and TCP `9001`, updates the app environment,
updates the managed firewall block, and restarts the managed Open Bridge Server
stack. MQTT authentication remains required. See
[0003: MQTT External Access Is Explicit Opt-In](decisions/0003-mqtt-external-access-opt-in.md).

## TLS Trust Onboarding

Open Bridge OS uses a local CA per appliance instance for LAN/default TLS.
Trust must be explicit and verifiable through an out-of-band path such as local
console, attached display, or a future boot-accessible trust summary.

The web onboarding page may display trust fingerprints, but the web page alone
is not sufficient proof before the client trusts the appliance instance.

Administrators with their own DNS name or PKI should be able to replace the
local certificate path later.

## Host Hardening

Provisioning applies:

- nftables firewall rules from `packaging/nftables/obos.nft`
- nginx TLS reverse proxy config from `packaging/nginx/openbridgeserver.conf`
- sysctl baseline from `packaging/sysctl/99-obos-hardening.conf`
- SSH service disablement when `ssh.service` exists

Manual remote development installs can preserve SSH temporarily with:

```sh
sudo OBOS_DISABLE_SSH=0 scripts/bootstrap/provision-debian.sh
```

See [hardening.md](hardening.md).

## Security Baseline Audit

Provisioned systems should pass:

```sh
sudo /usr/lib/obos/security-baseline.sh
```

The manual validation plan is documented in
[security-baseline-testplan.md](security-baseline-testplan.md).

## Container Runtime

The first version uses Docker Compose because it matches the upstream Open
Bridge Server deployment.

Current container baseline:

- least-needed published ports
- service-level `no-new-privileges:true`
- `init: true` for signal handling and child reaping
- explicit restart policy
- persistent volumes below `/srv/obos`
- health checks for both Open Bridge Server and Mosquitto
- no arbitrary Compose editing through the web UI

Future hardening should include:

- pinned image tags or digests once release images are available
- capability drops after validating the Mosquitto password-file bootstrap path
- read-only root filesystems where compatible
- Docker user namespace remapping compatibility testing

## Updates

A successful `obosctl update` should leave an audit-friendly state record at
`/srv/obos/state/last-update`. The record should include the completion time,
app name, managed service, backup path, and successful localhost plus verified
HTTPS proxy health markers.

Failed updates must not overwrite the last successful update record. This keeps
status output and future web UI state honest: stale success remains visibly old
instead of being replaced by a failed attempt.

## Backup and Restore

Backups should include:

- Open Bridge Server data
- Mosquitto persistent data
- obos app environment files
- appliance identifier
- TLS trust material when restoring the same appliance identity
- obos appliance metadata needed for restore

Each backup archive should include a root-level `obos-backup-manifest.txt` that
records the creation time, app name, appliance identifier, and whether the
archive contains secrets and TLS material. The manifest is metadata for humans,
future restore tooling, and support triage; it does not make the backup less
sensitive.

Backups should not include:

- transient container layers
- package caches
- logs by default, unless selected

Backup export should warn when secrets and TLS private key material are included.

## Open Questions

- Should obos use full disk encryption on x86_64 installations, and what is
  the equivalent story for Raspberry Pi unattended boot?
- Should Docker be replaced or constrained further once the first appliance
  image has been validated?
- What is the exact UI flow for local CA trust installation on phones/tablets?
