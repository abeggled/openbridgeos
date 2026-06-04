# open bridge operating system

Languages: [English](README.md) | [Deutsch](README.de.md)

open bridge operating system (obos) is a security-focused Debian appliance for running
open bridge server with minimal setup effort.

The target user should be able to write an image to a USB stick or SD card,
boot it on Raspberry Pi 4+ or x86_64 hardware, open a browser, and operate a
ready-to-use open bridge server installation without managing Linux packages,
Docker images, Compose files, volumes, or update workflows manually.

## Scope

obos is intentionally not a second building automation UI. open bridge server
remains responsible for adapters, data points, bindings, logic, visualization,
users, API keys, and MQTT access.

obos manages the appliance layer:

- first boot setup
- host identity, network, timezone, and system access
- open bridge server lifecycle
- container runtime updates
- system updates
- health checks and logs
- backup and restore orchestration
- host hardening
- image builds for Raspberry Pi and x86_64

## Initial Architecture

Version 0.1 is planned as:

- Debian 13 Trixie minimal base system
- Docker Engine with Compose v2 from Debian packages
- nginx TLS reverse proxy on TCP `443`
- nftables default-drop host firewall
- sysctl hardening baseline
- SSH disabled by default when present
- open bridge server and Mosquitto as the primary managed app
- persistent application data below `/srv/obos`
- a small local `obos-agent` service
- a web UI for appliance administration

See [docs/architecture.md](docs/architecture.md),
[docs/security.md](docs/security.md),
[docs/hardening.md](docs/hardening.md), and
[docs/decisions/0001-target-debian-trixie.md](docs/decisions/0001-target-debian-trixie.md).

## Development Install

The first development path targets a fresh Debian 13 host:

```sh
sudo scripts/bootstrap/provision-debian.sh
sudo reboot
```

For remote development installs over SSH, read [docs/install-debian.md](docs/install-debian.md)
first. The default hardening policy disables SSH when present.

See [docs/install-debian.md](docs/install-debian.md) and
[docs/image-build.md](docs/image-build.md).

## Hardware

See [docs/hardware.md](docs/hardware.md) for Raspberry Pi 4+ and x86_64 sizing,
storage, power, and recovery guidance.

## Security Baseline

After provisioning and reboot, validate the appliance with:

```sh
sudo /usr/lib/obos/security-baseline.sh
```

See [docs/security-baseline-testplan.md](docs/security-baseline-testplan.md).

## TLS Trust

The planned release TLS model uses a local CA per appliance instance. The first
helpers can already generate trust material, print fingerprints, and export a
public trust bundle:

```sh
sudo obosctl tls-generate
sudo obosctl tls-info
sudo obosctl tls-export
```

open bridge server is exposed through the local TLS reverse proxy on TCP `443`.
The direct OBS HTTP port binds to `127.0.0.1:8080` only.

See [docs/tls-trust.md](docs/tls-trust.md).

## Administration

The first appliance administration interface is `obosctl`:

```sh
obosctl status
sudo obosctl backup
sudo obosctl update
```

See [docs/admin-cli.md](docs/admin-cli.md).

## Repository Layout

```text
apps/
  openbridgeserver/        Managed open bridge server app definition
docs/
  admin-cli.md             Local appliance administration commands
  architecture.md          System shape and design decisions
  decisions/               Architecture decision records
  hardening.md             Host firewall, SSH, and sysctl hardening
  hardware.md              Hardware sizing, storage, and power guidance
  install-debian.md        First Debian development install path
  image-build.md           Bootable image profile and build plan
  security-baseline-testplan.md  First VM security validation plan
  security.md              Security model and hardening principles
  tls-trust.md             Local CA trust material notes
  roadmap.md               MVP phases
packaging/
  apt/                     Debian unattended security update policy
  docker/                  Docker daemon defaults
  images/                  Bootable image profiles
  nginx/                   TLS reverse proxy config
  nftables/                Host firewall rules
  sysctl/                  Host kernel/network hardening
  systemd/                 Host services and timers
scripts/
  audit/                   Target-system audit scripts
  bootstrap/               First boot and host provisioning scripts
  checks/                  CI validation helpers
  hardening/               Host hardening helpers
  images/                  Image profile validation and build-plan helpers
  tls/                     TLS trust helper scripts
```

## Security

Security is part of the product surface, not an optional hardening pass. See
[SECURITY.md](SECURITY.md) for reporting expectations and
[docs/security.md](docs/security.md) for the initial appliance security model.

## Status

Early project bootstrap. The first milestone is a bootable Debian-based image
that starts open bridge server reliably and exposes a small local
administration surface for appliance operations.
