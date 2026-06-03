# Open Bridge OS

Open Bridge OS (obos) is a security-focused Debian appliance for running
Open Bridge Server with minimal setup effort.

The target user should be able to write an image to a USB stick or SD card,
boot it on Raspberry Pi 4+ or x86_64 hardware, open a browser, and operate a
ready-to-use Open Bridge Server installation without managing Linux packages,
Docker images, Compose files, volumes, or update workflows manually.

## Scope

obos is intentionally not a second building automation UI. Open Bridge Server
remains responsible for adapters, data points, bindings, logic, visualization,
users, API keys, and MQTT access.

obos manages the appliance layer:

- first boot setup
- host identity, network, timezone, and system access
- Open Bridge Server lifecycle
- container runtime updates
- system updates
- health checks and logs
- backup and restore orchestration
- image builds for Raspberry Pi and x86_64

## Initial Architecture

Version 0.1 is planned as:

- Debian minimal base system
- Docker Engine with the Compose plugin
- Open Bridge Server and Mosquitto as the primary managed app
- persistent application data below `/srv/obos`
- a small local `obos-agent` service
- a web UI for appliance administration

See [docs/architecture.md](docs/architecture.md) and
[docs/security.md](docs/security.md).

## Repository Layout

```text
apps/
  openbridgeserver/        Managed Open Bridge Server app definition
docs/
  architecture.md          System shape and design decisions
  security.md              Security model and hardening principles
  roadmap.md               MVP phases
packaging/
  systemd/                 Host services and timers
scripts/
  bootstrap/               First boot and host provisioning scripts
```

## Security

Security is part of the product surface, not an optional hardening pass. See
[SECURITY.md](SECURITY.md) for reporting expectations and
[docs/security.md](docs/security.md) for the initial appliance security model.

## Status

Early project bootstrap. The first milestone is a bootable Debian-based image
that starts Open Bridge Server reliably and exposes a small local
administration surface for appliance operations.
