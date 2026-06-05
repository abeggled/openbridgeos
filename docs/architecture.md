# Architecture

open bridge operating system is an appliance layer around open bridge server.

The project should stay boring in the best possible way: standard Debian,
standard container runtime, predictable filesystem layout, conservative update
behavior, and explicit security boundaries.

## System Layers

```text
Hardware or VM
  Debian minimal
    systemd
    nftables
    nginx TLS reverse proxy
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

open bridge server owns building automation:

- adapter configuration
- datapoints and bindings
- logic editor
- visualization
- user and API key management
- MQTT account management
- open bridge server backup and restore format

open bridge operating system owns the appliance:

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

- open bridge server already ships a Compose stack.
- The stack contains both open bridge server and Mosquitto.
- Current operation depends on shared volumes for Mosquitto password handling.
- The Compose model is easy to inspect and debug for early adopters.
- Multi-architecture images are already part of the open bridge server build
  target.

Podman can be evaluated later, but it should not block the first appliance
image.

## Filesystem Layout

```text
/etc/obos/
  appliance-id
  obos.yaml
  apps/
    openbridgeserver.env
  tls/
    obos-local-ca.crt
    obos-local-ca.key
    obos.local.crt
    obos.local.key

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
    portable-backups/
    portable-imports/
    restore-staging/
    trust/
  web/
    index.html
    styles.css
    app.js
```

The goal is that every persistent piece of user data lives below `/srv/obos`
or is explicitly exported by backup tooling. Sensitive appliance identity and
trust material below `/etc/obos` must be included deliberately in backups.

## Network Defaults

The default appliance should expose only the minimum useful surface:

- `443/tcp` for nginx TLS reverse proxy
- `127.0.0.1:8080` for open bridge server behind the proxy
- `127.0.0.1:1883` for MQTT unless LAN MQTT is explicitly enabled
- `127.0.0.1:9001` for MQTT over WebSocket unless explicitly enabled

Plain HTTP on TCP `80` is closed for now. Remote shell access should be opt-in
or clearly surfaced during first setup.

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

## Web UI Agent Contract

The appliance web UI should use a local allowlisted agent around stable
`obosctl` commands. The current command contract is documented in
[web-ui-agent-contract.md](web-ui-agent-contract.md).

`apps/obos-web` is a static appliance console installed below `/srv/obos/web`.
nginx serves it below `/obos/` on the same HTTPS origin while leaving `/` for
open bridge server. `/obos/` and `/obos/api/` are protected by per-appliance
Basic Auth credentials generated during first boot.

The web console reads status, host basics, update state, backups, restore
staging, MQTT exposure, TLS trust, logs metadata, security baseline, technical
MVP readiness, and agent audit state through `obos-agent-http.service`. The
bridge binds to `127.0.0.1:8091`, is exposed by nginx below `/obos/api/`, calls
the installed `obos-agent` binary, and never exposes a raw shell.

Confirmed HTTP mutations are enabled only for allowlisted workflows: service
start/stop/restart, update, backup creation, encrypted portable backup export
and download, encrypted portable backup upload and private import staging,
restore staging, hostname/timezone changes, MQTT LAN opt-in/opt-out, TLS
generation/export, and web console password rotation. Restore apply remains
CLI-only until a separate browser-safe review adds stronger confirmation and
rollback UX.

Because `obos-agent` currently crosses the privilege boundary with `sudo -n`,
the HTTP bridge must not use `NoNewPrivileges=true` until that sudo dependency
is removed. The detailed command and HTTP contract is in
[web-ui-agent-contract.md](web-ui-agent-contract.md).
