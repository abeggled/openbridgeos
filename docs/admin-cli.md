# obosctl

`obosctl` is the first appliance administration interface for open bridge operating system.
It is intentionally small and maps directly to operations that the later web UI
and agent will need as well.

## Commands

```sh
obosctl status
obosctl status-summary
obosctl system-summary
sudo obosctl set-hostname obos-test
sudo obosctl set-timezone Europe/Zurich
sudo obosctl security-summary
sudo obosctl agent-audit-summary
obosctl health
obosctl proxy-health
obosctl restore-inspect <backup.tar.gz>
obosctl restore-plan <backup.tar.gz>
sudo obosctl restore-stage <backup.tar.gz>
sudo obosctl restore-stage-inspect <stage-dir>
sudo obosctl restore-stage-summary
sudo obosctl restore-apply-plan <stage-dir>
sudo obosctl start
sudo obosctl stop
sudo obosctl restart
sudo obosctl update
obosctl update-summary
sudo obosctl backup
obosctl backup-list
obosctl logs
sudo obosctl logs-summary
sudo obosctl logs-tail
sudo obosctl portable-export-plan <backup.tar.gz>
sudo obosctl portable-import-plan <portable-backup>
sudo obosctl tls-generate
obosctl tls-status
obosctl tls-summary
sudo obosctl tls-info
sudo obosctl tls-export
sudo obosctl tls-export-boot
sudo obosctl mqtt-status
sudo obosctl mqtt-summary
sudo obosctl mqtt-enable-lan
sudo obosctl mqtt-enable-lan 192.168.1.0/24
sudo obosctl mqtt-disable-lan
```

## Status

```sh
obosctl status
obosctl status-summary
obosctl system-summary
sudo obosctl set-hostname obos-test
sudo obosctl set-timezone Europe/Zurich
sudo obosctl security-summary
sudo obosctl agent-audit-summary
```

Shows the systemd unit state, Docker Compose service state, the localhost open
bridge server health endpoint result, and the HTTPS reverse proxy health result.
The HTTPS proxy check verifies the response through the per-appliance-instance
local CA by resolving `obos.local` to `127.0.0.1` for the local probe.

If `/srv/obos/state/last-update` exists, `status` also prints the last
successful update record.

`status-summary` prints a stable key-value format for agents and the future web
UI. It includes a format version, app name, service name, systemd active state,
localhost health, HTTPS proxy health, and whether a last update record exists.

`system-summary` prints the stable `obos-system-summary-v1` format for agents
and the web UI. It includes hostname, timezone, whether a default route is
present, and the primary interface name. It does not print IP addresses.

`set-hostname` and `set-timezone` update appliance host basics after validating
their input. The web UI uses the same commands through confirmed `obos-agent`
mutations.

`security-summary` runs the security baseline audit in machine-readable mode. It
prints the summary format, PASS/FAIL result, pass count, and fail count for
agents and the future web UI.

`agent-audit-summary` prints metadata-only mutation audit status for the local
agent. It reports whether the audit log exists, how many agent mutation entries
are present, and recent `obos-agent-audit-v1` events.

```sh
obosctl health
obosctl proxy-health
```

`health` checks the internal localhost open bridge server endpoint.
`proxy-health` checks the nginx HTTPS boundary with local CA verification.

## Logs

```sh
obosctl logs
sudo obosctl logs-summary
sudo obosctl logs-tail
```

`logs` follows the open bridge server Docker Compose logs for an interactive
administrator.

`logs-summary` prints the stable `obos-logs-summary-v1` format for agents and
the web UI. It is metadata-only and reports whether raw logs are exposed,
whether `journalctl` and Docker are available, and how many journal entries were
seen for the service in the last hour. It does not print raw log lines.

`logs-tail` prints the stable `obos-logs-tail-v1` format with a bounded recent
tail from the open bridge server systemd unit and Compose stack. It does not
accept paths, queries, or a custom shell command.

## Update

```sh
sudo obosctl update
obosctl update-summary
sudo obosctl update-rollback-plan
```

The update command performs the first conservative update flow:

1. Create a timestamped backup.
2. Pull newer container images.
3. Restart the managed systemd service.
4. Poll the localhost and HTTPS proxy health endpoints for up to 60 seconds.
5. Write `/srv/obos/state/last-update` after both health checks pass.

If the pre-update backup is not created or cannot be found, the update is
blocked before images are pulled or services are restarted.

If either health check fails, the command exits non-zero and does not update the
last successful update record. Automatic rollback is not implemented yet.

The update record is a small key-value file with format `obos-update-v1`. It
includes the completion timestamp, app name, systemd service name, pre-update
backup requirement, backup path, and successful local/proxy health markers.

`update-summary` prints a stable key-value format for agents and the future web
UI. It includes the update state file path, whether a successful update record is
present, and the last update record fields when present.

`update-rollback-plan` is read-only and non-destructive. It reads the last
successful update record, verifies that the recorded backup still exists and
passes backup inspection, then prints the restore planning commands to use before
any future apply workflow.

## Backup

```sh
sudo obosctl backup
obosctl backup-summary
obosctl backup-list
obosctl backup-prune-plan
obosctl backup-prune
sudo obosctl backup-prune --confirm backup-prune
sudo obosctl portable-export-plan <backup.tar.gz>
sudo obosctl portable-export <backup.tar.gz> <passphrase-file>
sudo obosctl portable-import-plan <portable-backup>
sudo obosctl portable-import-stage <portable-backup> <passphrase-file>
```

Backups are written to `/srv/obos/backups` by default and are mode `0600`.
They include:

- `obos-backup-manifest.txt` with creation time, app name, appliance identifier, and secret/TLS inclusion flags
- open bridge server app data
- Mosquitto data
- Compose files and Mosquitto config
- generated app environment file
- appliance identifier from `/etc/obos/appliance-id`
- TLS identity material below `/etc/obos/tls`, when present

The backup contains secrets, including the open bridge server JWT secret,
internal MQTT service password, and TLS private key material. Treat exported
backups as sensitive data. Restoring the appliance identifier and TLS material
preserves the appliance instance identity and avoids forcing clients to trust a
new local CA.

Mosquitto logs are excluded by default. The backup manifest records this with
`includes_logs=false`.

The web UI can trigger the same operation through
`obos-agent backup --confirm backup` via the local HTTP bridge. Raw backup
archive download is intentionally not exposed through the web UI because backups
contain secret-bearing appliance configuration.

The web UI can also trigger `start`, `stop`, `restart`, and `update` through the
same local HTTP bridge confirmation model. These operations still cross the
`obos-agent` audit boundary and use the same confirmation token as the agent
command.

The web UI can enable or disable MQTT LAN exposure through the same local HTTP
bridge. Enabling MQTT accepts an optional source CIDR, which `obos-agent`
validates before calling `sudo obosctl mqtt-enable-lan`.

The web UI can also generate TLS material and export the public trust bundle
through confirmed `tls-generate` and `tls-export` mutations. TLS generation
preserves existing appliance identity material instead of rotating it
implicitly.

The web UI can stage the latest listed backup through `obos-agent restore-stage
<backup.tar.gz> --confirm restore-stage`. This extracts into private restore
staging only; restore apply remains unavailable through the web UI.

Downloadable backups use the encrypted portable backup format
`obos-portable-backup-v1`, not raw appliance backup archives. The web UI can
create an encrypted portable export from the latest listed backup through
`obos-agent portable-export <backup.tar.gz> <passphrase-file> --confirm
portable-export` and then download only the resulting portable export artifact
from `/srv/obos/state/portable-backups`. Import must decrypt into private
staging, run backup inspection, and then use the existing restore staging and
apply planning gates.

`portable-export-plan` is read-only and non-destructive. It first verifies the
selected local backup with `restore-inspect`, then prints the stable
`obos-portable-backup-export-plan-v1` format. The plan records that raw backup
download is not allowed, authenticated encryption is required, and download may
only happen after encryption.

`portable-export` creates a passphrase-encrypted `obos-portable-backup-v1`
archive below `/srv/obos/state/portable-backups`. It verifies the local backup
first, encrypts the payload with GnuPG symmetric encryption using the supplied
passphrase file, and writes cleartext metadata with backup manifest and payload
SHA-256 hashes. The passphrase itself is never passed on the command line.

`portable-import-plan` is read-only and non-destructive. It accepts only paths
below `/srv/obos/state/portable-imports`, prints
`obos-portable-backup-import-plan-v1`, and records that import must decrypt into
private staging, verify hashes, run backup inspection, require restore staging,
and disallow live apply.

`portable-import-stage` decrypts an uploaded portable backup from
`/srv/obos/state/portable-imports` into a private import staging directory. It
verifies the portable metadata, encrypted payload hash, decrypted backup hash,
and runs `restore-inspect` before reporting the staged backup path. It still
does not apply anything to the live appliance.

`backup-summary` prints the latest backup state for agents and the future web
UI, including whether the latest archive passes backup inspection and whether
its manifest records secrets, logs, and TLS private keys. `backup-list` prints a
stable key-value inventory with one line per matching backup. Backup archives
contain secrets, so UI download flows must still treat every listed file as
sensitive.

`backup-prune-plan` prints a non-destructive retention plan. It reports which
backups would be kept by the current keep count and which older backups would be
delete candidates. `backup-prune` defaults to a dry run and prints the same
delete candidates as `would_delete=` records. It deletes old backups only when
called with the explicit `--confirm backup-prune` token.

## Restore Inspection

```sh
obosctl restore-inspect /srv/obos/backups/obos-openbridgeserver-20260604T103000Z.tar.gz
```

`restore-inspect` is a non-destructive preflight check for appliance backups. It
reads the archive manifest, rejects unsafe archive paths such as absolute paths
or `..` traversal, verifies required restore inputs, and reports whether TLS
private key material is present.

Required archive entries for a complete restore candidate:

- `obos-backup-manifest.txt`
- `appliance-id`
- generated app environment file
- `data/`
- `mqtt/`
- `compose.yaml`
- `mosquitto.conf`

TLS private key material is reported separately because it determines whether a
restore can preserve the same appliance TLS identity. The command does not stop
services and does not extract files.

## Restore Plan

```sh
obosctl restore-plan /srv/obos/backups/obos-openbridgeserver-20260604T103000Z.tar.gz
```

`restore-plan` first runs the same non-destructive inspection. If the backup is a
valid restore candidate, it prints the planned target paths, service order,
permission normalization step, health checks, security audit step, and whether
TLS private key material is present. It still does not stop services and does not
extract files.

## Restore Staging

```sh
sudo obosctl restore-stage /srv/obos/backups/obos-openbridgeserver-20260604T103000Z.tar.gz
sudo obosctl restore-stage-summary
obos-agent restore-stage /srv/obos/backups/obos-openbridgeserver-20260604T103000Z.tar.gz --confirm restore-stage
```

`restore-stage` first runs the same backup inspection and then extracts the
backup into a private mode `0700` staging directory below
`/srv/obos/state/restore-staging`. It does not stop services and does not replace
live appliance files. It also writes a mode `0600` `obos-restore-stage.txt`
manifest that records the source backup, stage path, app, service, staged-only
mode, and TLS private key presence. The staging directory contains sensitive data
and should be treated like the original backup.

`restore-stage-summary` prints a machine-readable inventory of existing private
restore staging directories. It reports whether each stage manifest exists and
whether `restore-stage-inspect` passes for that staging directory.

Through `obos-agent`, restore staging is a confirmed mutation. The agent accepts
only appliance backup archives below the configured backup directory before
calling `sudo obosctl restore-stage`.

## Restore Stage Inspection

```sh
sudo obosctl restore-stage-inspect /srv/obos/state/restore-staging/restore.XXXXXXXX
obos-agent restore-stage-inspect /srv/obos/state/restore-staging/restore.XXXXXXXX
```

`restore-stage-inspect` verifies an already extracted staging directory before a
future apply step is allowed to use it. It checks the stage manifest format,
staged-only mode, expected app name, required restore inputs, and confirms that
Mosquitto logs were not staged. The command does not stop services and does not
replace live appliance files.

Through `obos-agent`, restore stage inspection accepts only staging directories
below the configured private restore staging directory.

## Restore Apply Plan

```sh
sudo obosctl restore-apply-plan /srv/obos/state/restore-staging/restore.XXXXXXXX
obos-agent restore-apply-plan /srv/obos/state/restore-staging/restore.XXXXXXXX
```

`restore-apply-plan` first requires restore stage inspection to pass. It then
prints the future live target paths, required pre-restore backup gate, explicit
confirmation requirement, service stop/restart order, permission normalization,
health checks, and security baseline audit step. It is still non-destructive and
does not replace live appliance files.

Through `obos-agent`, restore apply planning uses the same private staging path
validation as restore stage inspection.

## MQTT LAN Access

```sh
sudo obosctl mqtt-status
sudo obosctl mqtt-summary
sudo obosctl mqtt-enable-lan
sudo obosctl mqtt-disable-lan
```

MQTT is localhost-only by default. `mqtt-enable-lan` deliberately exposes MQTT
plain TCP on `1883` and MQTT WebSocket on `9001` by updating the app environment
file, updating the managed nftables block, reloading the firewall, and
restarting the managed open bridge server stack.

`mqtt-summary` prints a stable key-value format for agents and the future web
UI. It includes the app environment file, MQTT bind addresses, and a derived
`lan_enabled` marker. It also reports the managed nftables source scope as
`firewall_source`, using `disabled`, `any`, a CIDR value, or `unknown`. The UI
should treat `lan_enabled=true` as a deliberate external exposure state.

Pass an IPv4 or IPv6 CIDR to restrict the firewall allow rules to a source
network while still publishing the MQTT listeners on the host:

```sh
sudo obosctl mqtt-enable-lan 192.168.1.0/24
sudo obosctl mqtt-enable-lan fd00::/64
```

`mqtt-disable-lan` restores both MQTT listeners to localhost and removes the
firewall allow rules. MQTT authentication remains required in both modes.

## TLS Trust

```sh
sudo obosctl tls-generate
obosctl tls-status
obosctl tls-summary
sudo obosctl tls-info
sudo obosctl tls-export
sudo obosctl tls-export-boot
```

`tls-generate` creates the per-appliance-instance local CA and leaf certificate
material below `/etc/obos/tls`. It preserves existing TLS material instead of
rotating appliance identity implicitly. `tls-status` checks the local CA and leaf
certificate status, including expiry warnings. `tls-summary` prints a stable
key-value format for agents and the future web UI with certificate presence,
paths, subjects, issuers, expiry states, expiry warnings, and SHA-256
fingerprints. `tls-info` prints the appliance hostname, IP addresses,
certificate paths, and SHA-256 fingerprints.
`tls-export` writes a public trust bundle below `/srv/obos/state/trust`.
`tls-export-boot` writes the public trust summary and local CA certificate to a
mounted boot partition when one is available.

The trust bundle contains the local CA certificate, the current leaf
certificate, and a text summary. It does not contain private keys. Verify the CA
fingerprint through an out-of-band path before installing the CA certificate on
client devices.

## Environment Overrides

For development or image tests, these paths can be overridden:

```sh
OBOS_APP_DIR=/tmp/obos/apps/openbridgeserver \
OBOS_ENV_FILE=/tmp/obos/etc/openbridgeserver.env \
OBOS_BACKUP_DIR=/tmp/obos/backups \
OBOS_STATE_DIR=/tmp/obos/state \
obosctl status
```

TLS, proxy health, and MQTT helper paths can also be overridden for tests:

```sh
OBOS_TLS_CA_CERT=/tmp/tls/obos-local-ca.crt \
OBOS_PROXY_HEALTH_HOST=obos.local \
OBOS_PROXY_HEALTH_URL=https://obos.local/api/v1/system/health \
OBOS_TLS_GENERATE_SCRIPT=/tmp/generate-tls-material.sh \
OBOS_TLS_STATUS_SCRIPT=/tmp/check-tls-status.sh \
OBOS_TLS_INFO_SCRIPT=/tmp/print-trust-info.sh \
OBOS_TLS_EXPORT_SCRIPT=/tmp/export-trust-bundle.sh \
OBOS_BOOT_TRUST_SCRIPT=/tmp/export-boot-trust-summary.sh \
OBOS_MQTT_LAN_SCRIPT=/tmp/set-mqtt-lan-access.sh \
obosctl proxy-health
```

## Design Notes

`obosctl` is not meant to replace open bridge server's own UI. It only manages
the appliance layer: lifecycle, health, logs, updates, backups, restore
preflight checks, local trust onboarding helpers, and explicit host exposure
changes.
