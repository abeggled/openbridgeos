# Security Model

open bridge operating system should inherit the security posture of open bridge server and
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
and [tls-trust.md](tls-trust.md). Client trust validation is tracked in
[client-ca-trust.md](client-ca-trust.md).

Target permissions:

```text
/etc/obos/                  root:root 0750
/etc/obos/appliance-id      root:root 0644
/etc/obos/apps/*.env        root:root 0600
/etc/obos/web.htpasswd      root:www-data 0640
/etc/obos/web-admin.env     root:root 0600
/etc/obos/tls/              root:root 0700
/srv/obos/                  root:root 0750
/srv/obos/state/            root:root 0750
/srv/obos/state/last-update root:root 0640
```

## Network Exposure

Default external exposure is minimal:

- HTTPS reverse proxy on `443/tcp`
- no external direct open bridge server HTTP
- no external SSH
- MQTT external access disabled by default
- obos administration UI behind the same TLS boundary and protected by GUI login
  with per-appliance-instance sessions

open bridge server binds to localhost behind nginx:

```text
127.0.0.1:8080
```

The host firewall uses nftables with inbound default-drop. It allows loopback,
established traffic, ICMP/IPv6 ICMP, DHCP renewals, and TCP `443`.

nginx serves `/obos/` as the appliance console and proxies `/obos/api/` to the
local agent bridge. The bridge requires a server-side session cookie after GUI
login. First boot exposes `/obos/onboarding/` and `/obos/api/v1/onboarding/` for
about five minutes after system start so the administrator can set the initial
`admin` password. The agent keys this window by the current system boot ID and
records when the window opened for that boot. A real reboot opens a fresh window
while stale marker timestamps cannot keep it closed, but a same-boot agent
restart does not extend the window. If the setup window expires before
credentials exist, rebooting opens a new window. The credential record is stored root-only in
`/etc/obos/web-admin.env`. Headless images may also export `OBOS-ONBOARDING.txt`
to a boot-accessible partition, but that file must not contain a password.

MQTT remains bound to localhost by default:

```text
127.0.0.1:1883
127.0.0.1:9001
```

Administrators can enable LAN MQTT access explicitly with:

```sh
sudo obosctl mqtt-enable-lan
sudo obosctl mqtt-enable-lan 192.168.1.0/24
```

That action exposes TCP `1883` and TCP `9001`, updates the app environment,
updates the managed firewall block, and restarts the managed open bridge server
stack. When a CIDR is supplied, the firewall rules are restricted to that source
network. MQTT authentication remains required. See
[0003: MQTT External Access Is Explicit Opt-In](decisions/0003-mqtt-external-access-opt-in.md).

## TLS Trust Onboarding

open bridge operating system uses a local CA per appliance instance for LAN/default TLS.
Trust must be explicit and verifiable through an out-of-band path such as local
console, attached display, or the boot-accessible trust summary.

The web onboarding page may display trust fingerprints, but the web page alone
is not sufficient proof before the client trusts the appliance instance.

Administrators with their own DNS name or PKI should be able to replace the
local certificate path later.

## Host Hardening

Provisioning applies:

- nftables firewall rules from `packaging/nftables/obos.nft`
- nginx TLS reverse proxy config from `packaging/nginx/openbridgeserver.conf`
- generated web console authentication files and session protected API config
- sysctl baseline from `packaging/sysctl/99-obos-hardening.conf`
- unattended Debian security updates without automatic reboots
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

The audit also verifies the local agent privilege boundary, including the
`obos-agent` system user, sudoers allowlist, logrotate policy, and restrictive
permissions for existing mutation audit logs.

The manual validation plan is documented in
[security-baseline-testplan.md](security-baseline-testplan.md).

## Container Runtime

The first version uses Docker Compose because it matches the upstream open
bridge server deployment.

Current container baseline:

- least-needed published ports
- service-level `no-new-privileges:true`
- `init: true` for signal handling and child reaping
- per-service `pids_limit` to reduce process-exhaustion blast radius
- explicit restart policy
- persistent volumes below `/srv/obos`
- health checks for both open bridge server and Mosquitto
- no arbitrary Compose editing through the web UI

Future hardening should include:

- pinned image tags or digests once release images are available
- capability drops after validating the Mosquitto password-file bootstrap path
- read-only root filesystems where compatible
- Docker user namespace remapping compatibility testing

Image pinning can be audited with
`scripts/images/check-compose-image-pinning.sh`; set
`OBOS_REQUIRE_PINNED_IMAGES=1` for broad release publication gates.

## Updates

Host security updates and application updates are intentionally separate.
Debian security updates are handled by `unattended-upgrades` for security
origins only, with automatic reboots disabled. open bridge server container
updates remain an explicit `obosctl update` action.

A successful `obosctl update` should leave an audit-friendly state record at
`/srv/obos/state/last-update`. The record should include the completion time,
app name, managed service, backup path, and successful localhost plus verified
HTTPS proxy health markers.

Failed updates must not overwrite the last successful update record. This keeps
status output and web UI state honest: stale success remains visibly old
instead of being replaced by a failed attempt.

## Backup and Restore

Backups should include:

- open bridge server data
- Mosquitto persistent data
- obos app environment files
- appliance identifier
- TLS trust material when restoring the same appliance identity
- obos appliance metadata needed for restore

Each backup archive should include a root-level `obos-backup-manifest.txt` that
records the creation time, app name, appliance identifier, and whether the
archive contains secrets and TLS material. The manifest is metadata for humans,
restore tooling, and support triage; it does not make the backup less
sensitive.

Restore handling starts with a non-destructive inspection step. The inspection
must reject unsafe archive paths, verify required restore inputs, and report
whether TLS private key material is present before any live appliance files are
replaced.

The next recovery step is a non-destructive restore plan that prints target
paths, service order, health checks, security audit expectations, and TLS
identity impact before any restore command modifies the appliance.

Restore staging may extract a validated backup into a private staging directory
for review, but it must not replace live files.

Staged restores must be inspected before any apply step. The stage inspection
verifies the restore stage manifest, staged-only mode, expected app name,
required restore inputs, and confirms that excluded Mosquitto logs were not
staged.

Restore apply planning remains non-destructive. The apply plan must require a
passing stage inspection, a fresh pre-restore backup, explicit CLI confirmation,
service stop/start ordering, permission normalization, post-restore health
checks, and a security baseline audit.

`obosctl restore-apply <stage-dir> --confirm restore-apply` is intentionally
CLI-only for the technical MVP. It creates a fresh pre-restore backup, replaces
only validated live appliance paths, normalizes permissions, restarts open
bridge server, verifies localhost and HTTPS proxy health, and records the
security baseline result. The web UI and HTTP bridge must not expose restore
apply until a separate browser-safe confirmation and rollback UX exists.

Backups should not include:

- transient container layers
- package caches
- logs by default, unless selected

Backup export should warn when secrets and TLS private key material are included.

## Encrypted Portable Backups

Raw appliance backups contain secrets and must not be exposed as browser
downloads. Downloadable backups use the separate encrypted portable backup
direction documented in
[0005-encrypted-portable-backups.md](decisions/0005-encrypted-portable-backups.md).

The intended portable format is `obos-portable-backup-v1`. It wraps a validated
local backup in an authenticated encryption envelope and records only non-secret
metadata next to the encrypted payload. Imports must decrypt into private
staging, verify metadata and hashes, run backup inspection, and then move through
restore staging. Uploading an encrypted portable backup must not directly apply
files to the live appliance.

## Open Questions

- Should obos use full disk encryption on x86_64 installations, and what is
  the equivalent story for Raspberry Pi unattended boot?
- Should Docker be replaced or constrained further once the first appliance
  image has been validated?
- What is the exact UI flow for local CA trust installation on phones/tablets?
