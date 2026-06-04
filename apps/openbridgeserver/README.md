# open bridge server App

This directory contains the obos-managed open bridge server deployment.

The app follows the upstream Docker Compose model: one open bridge server
container and one Mosquitto container with shared password management.

## Managed Files

```text
compose.yaml              obos Compose definition
mosquitto.conf            broker configuration
openbridgeserver.env      generated on first boot, not committed
```

At runtime these files are installed to:

```text
/srv/obos/apps/openbridgeserver/
```

Persistent data should remain below that directory so backup and restore can be
simple and auditable.

## Ports

Default ports:

- `8080/tcp` open bridge server web interface and API
- `1883/tcp` MQTT, optional external exposure
- `9001/tcp` MQTT over WebSocket, optional external exposure

The first obos release may expose only `8080/tcp` by default and keep MQTT
internal until enabled.
