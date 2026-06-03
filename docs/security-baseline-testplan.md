# Security Baseline Test Plan

This test plan validates the first Open Bridge OS security baseline on a fresh
Debian 13 VM after provisioning and reboot.

## Scope

Validate that the appliance starts Open Bridge Server while preserving the
intended host security posture:

- generated per-device secrets
- minimal network exposure
- nftables default-drop firewall
- SSH disabled by default
- Docker daemon hardening defaults
- sysctl hardening baseline
- Open Bridge Server health
- backup file permissions

## Test Setup

Use a fresh Debian 13 Trixie VM with console access.

For remote SSH-based development tests, keep SSH active during provisioning:

```sh
sudo OBOS_DISABLE_SSH=0 scripts/bootstrap/provision-debian.sh
```

For image-like testing, use the default behavior:

```sh
sudo scripts/bootstrap/provision-debian.sh
sudo reboot
```

## Fast Audit

After reboot, run:

```sh
sudo /usr/lib/obos/security-baseline.sh
```

Expected result:

```text
security baseline: PASS
```

Any `FAIL` line should be treated as a blocking issue for the baseline.

## Manual Checks

### Services

```sh
systemctl is-active docker.service
systemctl is-active nftables.service
systemctl is-enabled obos-first-boot.service
systemctl is-enabled obos-openbridgeserver.service
```

Expected:

- Docker active
- nftables active
- obos first boot enabled
- Open Bridge Server service enabled

### SSH

```sh
systemctl is-active ssh.service || true
nft list ruleset | grep 'tcp dport 22' || true
```

Expected for image-like testing:

- SSH inactive or absent
- no firewall rule for TCP `22`

### Firewall

```sh
sudo nft list ruleset
```

Expected inbound policy:

- input policy drop
- loopback accepted
- established/related accepted
- ICMP and IPv6 ICMP accepted
- DHCP client renewals accepted
- TCP `8080` accepted
- TCP `22`, `1883`, and `9001` not accepted externally

### Ports

From another host on the same network:

```sh
nmap -Pn -p 22,80,443,1883,9001,8080 <obos-ip>
```

Expected:

- `8080/tcp` open
- `22/tcp` closed or filtered
- `1883/tcp` closed or filtered
- `9001/tcp` closed or filtered
- `80/tcp` and `443/tcp` closed until the obos web UI/TLS story exists

### Secrets

```sh
sudo stat -c '%a %U:%G %n' /etc/obos /etc/obos/apps/openbridgeserver.env
sudo grep -E '^(OBS_JWT_SECRET|OBS_MQTT_PASSWORD)=' /etc/obos/apps/openbridgeserver.env
```

Expected:

- `/etc/obos` mode `750`
- app env file mode `600`
- JWT secret present and non-empty
- MQTT password present and non-empty
- no default placeholder secrets

### Docker

```sh
docker info --format '{{json .SecurityOptions}}'
docker info --format '{{.LoggingDriver}}'
```

Expected:

- security options include `name=no-new-privileges`
- logging driver is `local`

### Open Bridge Server

```sh
obosctl status
obosctl health
curl --fail http://127.0.0.1:8080/api/v1/system/health
```

Expected:

- obos service status visible
- health endpoint passes locally
- Open Bridge Server reachable on LAN port `8080`

### Backup Permissions

```sh
sudo obosctl backup
sudo ls -l /srv/obos/backups
```

Expected:

- backup is created
- backup file mode is not group/world readable
- backup is treated as sensitive because it contains secrets

## Exit Criteria

The baseline passes when:

- `sudo /usr/lib/obos/security-baseline.sh` exits `0`
- manual port scan matches the expected exposure
- Open Bridge Server health endpoint passes
- backup file permissions are restrictive

## Known Follow-Up Tests

- TLS/certificate baseline once HTTP hardening is designed
- full disk encryption feasibility
- Docker user namespace remapping compatibility
- update rollback and recovery drill
- Raspberry Pi 4+ boot and network behavior
