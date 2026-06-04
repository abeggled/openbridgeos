# Security Baseline Test Plan

This test plan validates the first open bridge operating system security baseline on a fresh
Debian 13 VM after provisioning and reboot.

## Scope

Validate that the appliance starts open bridge server while preserving the
intended host security posture:

- generated per-appliance-instance secrets
- stable appliance identifier
- generated per-appliance-instance TLS trust material
- HTTPS reverse proxy exposure on TCP `443`
- direct open bridge server HTTP closed externally
- verified HTTPS proxy health through the local CA
- minimal network exposure
- nftables default-drop firewall
- SSH disabled by default
- MQTT closed externally by default
- explicit MQTT LAN opt-in and disable workflow
- Docker daemon hardening defaults
- sysctl hardening baseline
- open bridge server health
- update state recording after successful updates
- backup file permissions and identity material coverage
- non-destructive restore inspection
- non-destructive restore planning
- private restore staging

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
systemctl is-active nginx.service
systemctl is-active nftables.service
systemctl is-enabled obos-first-boot.service
systemctl is-enabled obos-openbridgeserver.service
```

Expected:

- Docker active
- nginx active
- nftables active
- obos first boot enabled
- open bridge server service enabled

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
- TCP `443` accepted for the HTTPS reverse proxy
- TCP `22`, `80`, `8080`, `1883`, and `9001` not accepted externally by default

### MQTT LAN Opt-In

```sh
sudo obosctl mqtt-status
sudo obosctl mqtt-enable-lan
sudo grep -E '^(OBS_MQTT_HOST_PORT|OBS_MQTT_WS_HOST_PORT)=' /etc/obos/apps/openbridgeserver.env
sudo nft list ruleset | grep 'tcp dport 1883'
sudo nft list ruleset | grep 'tcp dport 9001'
sudo obosctl mqtt-enable-lan 192.168.1.0/24
sudo nft list ruleset | grep 'ip saddr 192.168.1.0/24 tcp dport 1883'
sudo nft list ruleset | grep 'ip saddr 192.168.1.0/24 tcp dport 9001'
sudo obosctl mqtt-disable-lan
sudo grep -E '^(OBS_MQTT_HOST_PORT|OBS_MQTT_WS_HOST_PORT)=' /etc/obos/apps/openbridgeserver.env
sudo nft list ruleset | grep 'tcp dport 1883' && false || true
sudo nft list ruleset | grep 'tcp dport 9001' && false || true
```

Expected:

- default status shows localhost MQTT bind addresses
- enable switches MQTT bind addresses to `0.0.0.0:1883` and `0.0.0.0:9001`
- enable adds firewall rules for TCP `1883` and `9001`
- enable with CIDR restricts firewall rules to the supplied source network
- disable restores localhost bind addresses
- disable removes firewall rules for TCP `1883` and `9001`

### Ports

From another host on the same network:

```sh
nmap -Pn -p 22,80,443,1883,9001,8080 <obos-ip>
```

Expected default baseline:

- `443/tcp` open
- `22/tcp` closed or filtered
- `80/tcp` closed or filtered
- `8080/tcp` closed or filtered
- `1883/tcp` closed or filtered
- `9001/tcp` closed or filtered

### Identity, Secrets, And TLS

```sh
sudo stat -c '%a %U:%G %n' /etc/obos /etc/obos/appliance-id /etc/obos/apps/openbridgeserver.env /etc/obos/tls
sudo grep -E '^[0-9a-f-]{36}$' /etc/obos/appliance-id
sudo grep -E '^(OBS_JWT_SECRET|OBS_MQTT_PASSWORD|OBS_HTTP_HOST_PORT)=' /etc/obos/apps/openbridgeserver.env
sudo obosctl tls-info
```

Expected:

- `/etc/obos` mode `750`
- appliance identifier file mode `644`
- app env file mode `600`
- `/etc/obos/tls` mode `700`
- appliance identifier present and UUID-shaped
- JWT secret present and non-empty
- MQTT password present and non-empty
- OBS HTTP bound to `127.0.0.1:8080`
- local CA and leaf fingerprints visible
- no default placeholder secrets

### Docker

```sh
docker info --format '{{json .SecurityOptions}}'
docker info --format '{{.LoggingDriver}}'
```

Expected:

- security options include `name=no-new-privileges`
- logging driver is `local`

### open bridge server

```sh
obosctl status
obosctl health
obosctl proxy-health
curl --fail http://127.0.0.1:8080/api/v1/system/health
curl --fail --cacert /etc/obos/tls/obos-local-ca.crt --resolve obos.local:443:127.0.0.1 https://obos.local/api/v1/system/health
```

Expected:

- obos service status visible
- localhost health endpoint passes
- HTTPS reverse proxy health endpoint passes with local CA verification
- open bridge server is not reachable externally on LAN port `8080`

### Update State

```sh
sudo obosctl update
sudo stat -c '%a %U:%G %n' /srv/obos/state /srv/obos/state/last-update
sudo grep '^format=obos-update-v1$' /srv/obos/state/last-update
sudo grep '^health_local=ok$' /srv/obos/state/last-update
sudo grep '^health_https_proxy=ok$' /srv/obos/state/last-update
obosctl status | grep 'last-update:'
```

Expected:

- update creates a backup before pulling images
- update succeeds only after localhost and verified HTTPS proxy health pass
- `/srv/obos/state` mode is `750`
- `/srv/obos/state/last-update` mode is `640`
- last update record is visible in `obosctl status`

### Backup Permissions And Contents

```sh
sudo obosctl backup
sudo ls -l /srv/obos/backups
latest_backup="$(sudo ls -1t /srv/obos/backups/obos-openbridgeserver-*.tar.gz | head -n 1)"
sudo tar -tzf "${latest_backup}" | grep '^obos-backup-manifest.txt$'
sudo tar -xOzf "${latest_backup}" obos-backup-manifest.txt | grep '^format=obos-backup-v1$'
sudo tar -xOzf "${latest_backup}" obos-backup-manifest.txt | grep '^contains_secrets=true$'
sudo tar -xOzf "${latest_backup}" obos-backup-manifest.txt | grep '^includes_logs=false$'
sudo tar -tzf "${latest_backup}" | grep '^appliance-id$'
sudo tar -tzf "${latest_backup}" | grep '^tls/obos-local-ca.key$'
sudo tar -tzf "${latest_backup}" | grep '^tls/obos.local.key$'
sudo tar -tzf "${latest_backup}" | grep '^mqtt/log' && false || true
obosctl restore-inspect "${latest_backup}"
obosctl restore-plan "${latest_backup}"
sudo obosctl restore-stage "${latest_backup}"
```

Expected:

- backup is created
- backup file mode is not group/world readable
- backup includes manifest metadata
- backup manifest marks the archive as secret-bearing
- backup manifest records that logs are excluded
- backup includes appliance identifier
- backup includes TLS private key material for appliance identity restore
- backup does not include Mosquitto logs by default
- restore inspection passes without extracting files
- restore plan prints target paths and identity impact without extracting files
- restore staging extracts into a private staging directory without replacing live files
- backup is treated as sensitive because it contains secrets and TLS private keys

## Exit Criteria

The baseline passes when:

- `sudo /usr/lib/obos/security-baseline.sh` exits `0`
- manual port scan matches the expected default exposure
- MQTT LAN opt-in and disable workflow behaves as expected
- open bridge server health endpoint passes through localhost and verified HTTPS proxy
- successful update records `/srv/obos/state/last-update`
- backup file permissions are restrictive
- backup contains manifest metadata, appliance identifier, and TLS identity material when TLS has been generated
- `obosctl restore-inspect` passes for the latest backup
- `obosctl restore-plan` passes for the latest backup
- `sudo obosctl restore-stage` creates a private staging directory for the latest backup

## Known Follow-Up Tests

- platform-specific CA import validation
- full disk encryption feasibility
- Docker user namespace remapping compatibility
- update rollback and recovery drill
- Raspberry Pi 4+ boot and network behavior
