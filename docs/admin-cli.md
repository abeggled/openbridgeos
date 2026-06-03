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
They include the Open Bridge Server app data, Mosquitto data, Compose files,
Mosquitto config, and the generated app environment file.

The backup contains secrets, including the Open Bridge Server JWT secret and
internal MQTT service password. Treat exported backups as sensitive data.

## Environment Overrides

For development or image tests, these paths can be overridden:

```sh
OBOS_APP_DIR=/tmp/obos/apps/openbridgeserver \
OBOS_ENV_FILE=/tmp/obos/etc/openbridgeserver.env \
OBOS_BACKUP_DIR=/tmp/obos/backups \
obosctl status
```

## Design Notes

`obosctl` is not meant to replace Open Bridge Server's own UI. It only manages
the appliance layer: lifecycle, health, logs, updates, and backups.
