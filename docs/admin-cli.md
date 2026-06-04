# obosctl

`obosctl` is the first appliance administration interface for open bridge operating system.
It is intentionally small and maps directly to operations that the later web UI
and agent will need as well.

## Commands

```sh
obosctl status
obosctl status-summary
obosctl health
obosctl proxy-health
obosctl restore-inspect <backup.tar.gz>
obosctl restore-plan <backup.tar.gz>
sudo obosctl restore-stage <backup.tar.gz>
sudo obosctl restore-stage-inspect <stage-dir>
sudo obosctl restore-apply-plan <stage-dir>
sudo obosctl start
sudo obosctl stop
sudo obosctl restart
sudo obosctl update
obosctl update-summary
sudo obosctl backup
obosctl backup-list
obosctl logs
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

```sh
obosctl health
obosctl proxy-health
```

`health` checks the internal localhost open bridge server endpoint.
`proxy-health` checks the nginx HTTPS boundary with local CA verification.

## Update

```sh
sudo obosctl update
obosctl update-summary
```

The update command performs the first conservative update flow:

1. Create a timestamped backup.
2. Pull newer container images.
3. Restart the managed systemd service.
4. Poll the localhost and HTTPS proxy health endpoints for up to 60 seconds.
5. Write `/srv/obos/state/last-update` after both health checks pass.

If either health check fails, the command exits non-zero and does not update the
last successful update record. Automatic rollback is not implemented yet.

The update record is a small key-value file with format `obos-update-v1`. It
includes the completion timestamp, app name, systemd service name, backup path,
and successful local/proxy health markers.

`update-summary` prints a stable key-value format for agents and the future web
UI. It includes the update state file path, whether a successful update record is
present, and the last update record fields when present.

## Backup

```sh
sudo obosctl backup
obosctl backup-list
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

`backup-list` prints a stable key-value inventory for agents and the future web
UI. It includes a format version, backup directory, one line per matching backup
with path, size, and mode, plus a final backup count. Backup archives contain
secrets, so UI download flows must still treat every listed file as sensitive.

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
```

`restore-stage` first runs the same backup inspection and then extracts the
backup into a private mode `0700` staging directory below
`/srv/obos/state/restore-staging`. It does not stop services and does not replace
live appliance files. It also writes a mode `0600` `obos-restore-stage.txt`
manifest that records the source backup, stage path, app, service, staged-only
mode, and TLS private key presence. The staging directory contains sensitive data
and should be treated like the original backup.

## Restore Stage Inspection

```sh
sudo obosctl restore-stage-inspect /srv/obos/state/restore-staging/restore.XXXXXXXX
```

`restore-stage-inspect` verifies an already extracted staging directory before a
future apply step is allowed to use it. It checks the stage manifest format,
staged-only mode, expected app name, required restore inputs, and confirms that
Mosquitto logs were not staged. The command does not stop services and does not
replace live appliance files.

## Restore Apply Plan

```sh
sudo obosctl restore-apply-plan /srv/obos/state/restore-staging/restore.XXXXXXXX
```

`restore-apply-plan` first requires restore stage inspection to pass. It then
prints the future live target paths, required pre-restore backup gate, explicit
confirmation requirement, service stop/restart order, permission normalization,
health checks, and security baseline audit step. It is still non-destructive and
does not replace live appliance files.

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
