# Host Hardening

Open Bridge OS treats host hardening as a default behavior, not as an optional
post-install checklist.

## Applied Defaults

Provisioning installs and applies:

- nftables host firewall
- sysctl hardening baseline
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
- allow TCP `8080` for Open Bridge Server UI/API
- drop other inbound traffic
- keep forwarding allowed so Docker networking is not broken accidentally
- keep outbound traffic allowed

MQTT is not opened in the firewall because the Compose defaults bind MQTT to
localhost only:

```text
127.0.0.1:1883
127.0.0.1:9001
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

## Design Boundaries

The current hardening layer is host-focused. It does not yet implement:

- TLS for Open Bridge Server
- image signing
- rollback for failed updates
- full disk encryption
- Docker daemon hardening beyond package defaults
