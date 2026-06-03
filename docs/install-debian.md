# Install on Debian 13

This document describes the first development installation path for Open Bridge
OS on a fresh Debian 13 Trixie system.

The goal is not yet a polished image build. The goal is a reproducible path
from a minimal Debian install to an appliance-like Open Bridge Server host.

## Target

- Debian 13 Trixie
- `amd64` or `arm64`
- root shell during provisioning
- network access for Debian packages and container image pulls

## Provisioning

From a checkout of this repository on the target system:

```sh
sudo scripts/bootstrap/provision-debian.sh
sudo reboot
```

Provisioning installs Docker, Compose, nftables, Open Bridge OS app files,
first boot logic, host hardening, `obosctl`, security baseline audit tooling,
and systemd units.

The first boot service intentionally generates secrets on the target device,
not during image creation.

## Remote Development Warning

Provisioning disables `ssh.service` by default if it exists. This is the desired
image behavior, but it can interrupt manual remote development installs.

For a temporary remote test install, preserve SSH with:

```sh
sudo OBOS_DISABLE_SSH=0 scripts/bootstrap/provision-debian.sh
```

The default firewall still does not open TCP 22.

## Expected Services

After reboot:

```sh
systemctl status obos-first-boot.service
systemctl status obos-openbridgeserver.service
systemctl status docker.service
systemctl status nftables.service
obosctl status
```

Open Bridge Server should be reachable at:

```text
http://<device-ip>:8080
```

MQTT is bound to localhost by default:

```text
127.0.0.1:1883
127.0.0.1:9001
```

## Security Baseline Audit

After reboot, run:

```sh
sudo /usr/lib/obos/security-baseline.sh
```

Expected result:

```text
security baseline: PASS
```

See [security-baseline-testplan.md](security-baseline-testplan.md).

## Administration

The first local administration interface is `obosctl`:

```sh
obosctl status
obosctl health
obosctl logs
sudo obosctl backup
sudo obosctl update
sudo obosctl restart
```

See [admin-cli.md](admin-cli.md).

## Persistent Paths

```text
/etc/obos/apps/openbridgeserver.env
/etc/nftables.conf
/etc/sysctl.d/99-obos-hardening.conf
/srv/obos/apps/openbridgeserver/data
/srv/obos/apps/openbridgeserver/mqtt
/srv/obos/backups
/srv/obos/state
```

## Security Notes

- `OBS_JWT_SECRET` is generated on first boot.
- `OBS_MQTT_PASSWORD` is generated on first boot.
- MQTT is not exposed to the LAN by default.
- nftables drops inbound traffic except Open Bridge Server on TCP `8080`.
- SSH is disabled by default when present.
- Backups contain secrets and are written with mode `0600`.

## Known Gaps

- No ISO or Raspberry Pi image builder yet.
- No obos web administration UI yet.
- No rollback path for failed app updates yet.
- No TLS/default certificate story yet.
