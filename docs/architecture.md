# Architecture

Open Bridge OS is an appliance layer around Open Bridge Server.

The project should stay boring in the best possible way: standard Debian,
standard container runtime, predictable filesystem layout, conservative update
behavior, and explicit security boundaries.

## System Layers

```text
Hardware or VM
  Debian minimal
    systemd
    Docker Engine + Compose plugin
    obos-agent
    obos-web
    /srv/obos
      apps/openbridgeserver
      backups
      state
      logs
```

## Responsibilities

Open Bridge Server owns building automation:

- adapter configuration
- datapoints and bindings
- logic editor
- visualization
- user and API key management
- MQTT account management
- Open Bridge Server backup and restore format

Open Bridge OS owns the appliance:

- first boot setup
- host updates
- container image updates
- service lifecycle
- system health
- persistent storage layout
- appliance backup orchestration
- image creation for Raspberry Pi and x86_64

## Runtime Decision

The initial runtime is Docker Compose.

Reasons:

- Open Bridge Server already ships a Compose stack.
- The stack contains both Open Bridge Server and Mosquitto.
- Current operation depends on shared volumes for Mosquitto password handling.
- The Compose model is easy to inspect and debug for early adopters.
- Multi-architecture images are already part of the Open Bridge Server build
  target.

Podman can be evaluated later, but it should not block the first appliance
image.

## Filesystem Layout

```text
/etc/obos/
  obos.yaml
  apps/
    openbridgeserver.env

/srv/obos/
  apps/
    openbridgeserver/
      compose.yaml
      mosquitto/
        mosquitto.conf
      data/
      mqtt/
      logs/
  backups/
  state/
```

The goal is that every persistent piece of user data lives below `/srv/obos`
or is explicitly exported by backup tooling.

## Network Defaults

The default appliance should expose only the minimum useful surface:

- `80/tcp` or `443/tcp` for the obos administration UI, once implemented
- `8080/tcp` for Open Bridge Server during the initial phase
- `1883/tcp` for MQTT only when enabled
- `9001/tcp` for MQTT over WebSocket only when enabled

Remote shell access should be opt-in or clearly surfaced during first setup.

## Update Model

Updates should be deliberate and recoverable:

1. Check for available OS, runtime, and app updates.
2. Show release notes or risk level where possible.
3. Create or prompt for a backup.
4. Pull new images.
5. Restart the affected stack.
6. Verify health checks.
7. Keep enough state to show the previous version and last update result.

Automatic unattended updates can be considered for security patches, but app
updates should start as explicit user actions.
