# obosctl

`obosctl` is the first appliance administration interface for Open Bridge OS.
It is intentionally small and maps directly to operations that the later web UI
and agent will need as well.

## Commands

```sh
obosctl status
obosctl health
sudo obosctl start
sudo obosctl stop
sudo obosctl restart
sudo obosctl update
sudo obosctl backup
obosctl logs
sudo obosctl tls-generate
sudo obosctl tls-info
sudo obosctl tls-export
```

## Status

```sh
obosctl status
```

Shows the systemd unit state, Docker Compose service state, and the Open Bridge
Server health endpoint result.

## Update

```sh
sudo obosctl update
```

The update command performs the first conservative update flow:

1. Create a timestamped backup.
2. Pull newer container images.
3. Restart the managed systemd service.
4. Poll the health endpoint for up to 60 seconds.

If the health check fails, the command exits non-zero. Automatic rollback is not
implemented yet.

## Backup

```sh
sudo obosctl backup
```

Backups are written to `/srv/obos/backups` by default and are mode `0600`.
They include:

- Open Bridge Server app data
- Mosquitto data
- Compose files and Mosquitto config
- generated app environment file
- TLS identity material below `/etc/obos/tls`, when present

The backup contains secrets, including the Open Bridge Server JWT secret,
internal MQTT service password, and TLS private key material. Treat exported
backups as sensitive data. Restoring the TLS material preserves the appliance
instance identity and avoids forcing clients to trust a new local CA.

## TLS Trust

```sh
sudo obosctl tls-generate
sudo obosctl tls-info
sudo obosctl tls-export
```

`tls-generate` creates the per-appliance-instance local CA and leaf certificate
material below `/etc/obos/tls`. `tls-info` prints the appliance hostname, IP
addresses, certificate paths, and SHA-256 fingerprints. `tls-export` writes a
public trust bundle below `/srv/obos/state/trust`.

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
obosctl status
```

TLS helper paths can also be overridden for tests:

```sh
OBOS_TLS_GENERATE_SCRIPT=/tmp/generate-tls-material.sh \
OBOS_TLS_INFO_SCRIPT=/tmp/print-trust-info.sh \
OBOS_TLS_EXPORT_SCRIPT=/tmp/export-trust-bundle.sh \
obosctl tls-info
```

## Design Notes

`obosctl` is not meant to replace Open Bridge Server's own UI. It only manages
the appliance layer: lifecycle, health, logs, updates, backups, and local trust
onboarding helpers.
