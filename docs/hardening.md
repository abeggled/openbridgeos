# Host Hardening

Open Bridge OS treats host hardening as a default behavior, not as an optional
post-install checklist.

## Applied Defaults

Provisioning installs and applies:

- nftables host firewall
- nginx TLS reverse proxy
- sysctl hardening baseline
- Docker daemon hardening defaults
- SSH disabled by default when `ssh.service` exists

The hardening entry point is:

```sh
sudo /usr/lib/obos/apply-host-hardening.sh
```

## Firewall

The default nftables policy is intentionally small:

- allow loopback
- allow established and related traffic
- allow ICMP and IPv6 ICMP
- allow DHCPv4 and DHCPv6 client renewals
- allow TCP `443` for the nginx TLS reverse proxy
- drop other inbound traffic
- keep forwarding allowed so Docker networking is not broken accidentally
- keep outbound traffic allowed

Open Bridge Server HTTP is not opened externally. It binds to localhost behind
nginx:

```text
127.0.0.1:8080
```

MQTT is not opened in the default firewall because the Compose defaults bind
MQTT to localhost only:

```text
127.0.0.1:1883
127.0.0.1:9001
```

LAN MQTT exposure must be an explicit opt-in workflow. Enabling it should update
both the Compose environment and firewall policy, and should remain visible to
the security baseline audit.

## TLS Reverse Proxy

nginx terminates HTTPS on TCP `443` using per-appliance-instance certificate
material below `/etc/obos/tls`.

The default proxy config is installed from:

```text
packaging/nginx/openbridgeserver.conf
```

First boot generates the local CA and leaf certificate before nginx starts.
Plain HTTP on TCP `80` is closed for now.

## SSH Policy

SSH is disabled by default if `ssh.service` exists.

This is deliberate for appliance images: physical or console access should be
used for initial recovery, and remote shell access should be an explicit choice.

During manual remote development installs, set this before provisioning if you
need to keep SSH active:

```sh
sudo OBOS_DISABLE_SSH=0 scripts/bootstrap/provision-debian.sh
```

To enable SSH later:

```sh
sudo apt-get install openssh-server
sudo /usr/lib/obos/enable-ssh.sh
```

The default firewall does not open TCP 22. If SSH is enabled intentionally, the
firewall policy must be reviewed as a separate administrative action.

## sysctl Baseline

The sysctl baseline reduces kernel information exposure and common network
weaknesses:

- restrict `dmesg`
- restrict kernel pointer exposure
- restrict ptrace
- disable unprivileged BPF where supported
- disable IPv4/IPv6 redirects and source routing
- enable IPv4 reverse path filtering
- enable TCP SYN cookies

## Docker Daemon Baseline

The Docker daemon config uses conservative operational hardening:

- `no-new-privileges` as a daemon default
- `live-restore` so containers are less coupled to daemon restarts
- local log driver with bounded log size and file count

The first baseline intentionally avoids user namespace remapping and broad
inter-container communication changes until the OBS/Mosquitto stack has been
validated under those constraints.

## Design Boundaries

The current hardening layer is host-focused. It does not yet implement:

- MQTT opt-in management command or UI
- image signing
- rollback for failed updates
- full disk encryption
- advanced Docker isolation such as user namespace remapping
