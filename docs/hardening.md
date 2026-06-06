# Host Hardening

open bridge operating system treats host hardening as a default behavior, not as an optional
post-install checklist.

## Applied Defaults

Provisioning installs and applies:

- nftables host firewall
- nginx TLS reverse proxy
- sysctl hardening baseline
- Docker daemon hardening defaults
- systemd unit hardening for obos-managed services
- unattended Debian security updates without automatic reboots
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

open bridge server HTTP is not opened externally. It binds to localhost behind
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

LAN MQTT exposure is an explicit opt-in workflow:

```sh
sudo obosctl mqtt-enable-lan
sudo obosctl mqtt-enable-lan 192.168.1.0/24
sudo obosctl mqtt-disable-lan
sudo obosctl mqtt-status
```

Enabling it updates both the Compose environment and the managed nftables block,
then restarts the firewall and open bridge server stack. When a CIDR is supplied,
the firewall allow rules are restricted to that source network. Disabling it
restores localhost-only bind addresses and removes the firewall allow rules.

## TLS Reverse Proxy

nginx terminates HTTPS on TCP `443` using per-appliance-instance certificate
material below `/etc/obos/tls`.

The obos web console and `/obos/api/` bridge are protected by nginx Basic Auth.
First boot generates `/etc/obos/web.htpasswd` and `/etc/obos/web-admin.env`.
The password hash file is readable by nginx only, and the credential record is
root-only. If `OBOS-ONBOARDING.txt` is exported to a boot-accessible partition,
remove it after onboarding because it contains the initial web console password.

The default proxy config is installed from:

```text
packaging/nginx/openbridgeserver.conf
```

First boot generates the local CA and leaf certificate before nginx starts.
Plain HTTP on TCP `80` is closed for now.

The reverse proxy also disables nginx server token disclosure and bounds client
header, request body, and send timeouts to avoid holding worker resources
indefinitely.

## systemd Unit Baseline

obos-managed units use conservative systemd sandboxing where it is compatible
with first boot and Docker Compose orchestration:

- `UMask=0077`
- `NoNewPrivileges=true`
- `PrivateTmp=true`
- `ProtectHome=true`
- `ProtectSystem=full`
- `LockPersonality=true`
- `MemoryDenyWriteExecute=true`
- `RestrictRealtime=true`
- `SystemCallArchitectures=native`

The first boot unit also declares explicit write access to `/etc/obos` and
`/srv/obos`, because it creates secrets, TLS material, and state markers there.

The security baseline audit verifies the enabled state and the shared sandboxing
properties for both obos-managed units on provisioned systems.
It also checks the local agent boundary: the `obos-agent` system user, sudoers
allowlist, logrotate policy, and restrictive permissions on existing mutation
audit logs.

More aggressive options such as `ProtectSystem=strict`, capability bounding, and
system call filtering should be tested against Docker Compose and the first boot
certificate path before becoming defaults.

## OS Security Updates

Provisioning installs `unattended-upgrades` and configures apt periodic updates
for Debian security origins only. Automatic package installation is enabled for
security updates, while automatic reboots are disabled.

This separates host CVE handling from application container updates: Debian
security fixes can land automatically, but reboot timing remains an explicit
appliance administration decision.

Installed policy files:

```text
/etc/apt/apt.conf.d/20auto-upgrades
/etc/apt/apt.conf.d/50unattended-upgrades
```

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

- automatic rollback for failed updates; explicit rollback staging and
  confirmed CLI restore apply are available
- full disk encryption
- advanced Docker isolation such as user namespace remapping

Release bundle signing is implemented through detached Minisign signatures and
strict manifest validation. Release key custody, publication policy, and image
digest pinning remain separate release operations to finalize before broad
distribution.
