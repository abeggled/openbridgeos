#!/usr/bin/env sh
set -eu

fail() {
  echo "security check failed: $1" >&2
  exit 1
}

! grep -R --exclude=check-security-defaults.sh "changeme\|password123\|secret123" \
  apps scripts packaging docs README.md SECURITY.md >/dev/null 2>&1 \
  || fail "default placeholder secret found"

grep -q 'APPLIANCE_ID_FILE=' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier path is not defined on first boot"

# shellcheck disable=SC2016
grep -Fq 'uuid > "${APPLIANCE_ID_FILE}"' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier is not generated on first boot"

grep -q 'APPLIANCE_ID_FILE=' scripts/obosctl \
  || fail "obosctl backup does not know the appliance identifier path"

grep -q 'appliance_id_name' scripts/obosctl \
  || fail "obosctl backup does not include appliance identifier"

grep -q 'APPLIANCE_ID_FILE=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit appliance identifier"

grep -q 'OBS_HTTP_HOST_PORT=127.0.0.1:8080' scripts/bootstrap/first-boot.sh \
  || fail "Open Bridge Server HTTP is not localhost-only by default"

grep -q 'OBS_MQTT_HOST_PORT=127.0.0.1:1883' scripts/bootstrap/first-boot.sh \
  || fail "MQTT plain listener is not localhost by default"

grep -q 'OBS_MQTT_WS_HOST_PORT=127.0.0.1:9001' scripts/bootstrap/first-boot.sh \
  || fail "MQTT websocket listener is not localhost by default"

# shellcheck disable=SC2016
grep -Fq 'OBS_JWT_SECRET=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "OBS JWT secret is not generated on first boot"

# shellcheck disable=SC2016
grep -Fq 'OBS_MQTT_PASSWORD=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "MQTT password is not generated on first boot"

grep -q 'TLS_GENERATE_SCRIPT=' scripts/bootstrap/first-boot.sh \
  || fail "TLS material is not generated on first boot"

grep -q 'nginx-light' scripts/bootstrap/provision-debian.sh \
  || fail "nginx reverse proxy package is not installed during provisioning"

grep -q 'systemctl enable nginx.service' scripts/bootstrap/provision-debian.sh \
  || fail "nginx service is not enabled during provisioning"

grep -q 'set-mqtt-lan-access.sh' scripts/bootstrap/provision-debian.sh \
  || fail "MQTT LAN opt-in helper is not installed during provisioning"

grep -q '"no-new-privileges": true' packaging/docker/daemon.json \
  || fail "Docker no-new-privileges default is not enabled"

grep -q '"log-driver": "local"' packaging/docker/daemon.json \
  || fail "Docker local log driver is not configured"

grep -q 'policy drop' packaging/nftables/obos.nft \
  || fail "nftables input policy is not default-drop"

grep -q 'tcp dport 443 accept' packaging/nftables/obos.nft \
  || fail "HTTPS reverse proxy port is not allowed"

! grep -q 'tcp dport 8080 accept' packaging/nftables/obos.nft \
  || fail "Direct Open Bridge Server HTTP is open in the default firewall"

! grep -q 'tcp dport 1883 accept' packaging/nftables/obos.nft \
  || fail "MQTT plain TCP is open in the default firewall"

! grep -q 'tcp dport 9001 accept' packaging/nftables/obos.nft \
  || fail "MQTT WebSocket is open in the default firewall"

grep -q 'OBOS MQTT LAN BEGIN' packaging/nftables/obos.nft \
  || fail "nftables MQTT LAN managed block is missing"

grep -q 'tcp dport 1883 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT plain TCP when enabled"

grep -q 'tcp dport 9001 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT WebSocket when enabled"

grep -q 'OBS_MQTT_HOST_PORT 0.0.0.0:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not publish MQTT plain TCP when enabled"

grep -q 'OBS_MQTT_HOST_PORT 127.0.0.1:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not restore localhost MQTT plain TCP"

grep -q 'udp sport 67 udp dport 68 accept' packaging/nftables/obos.nft \
  || fail "DHCPv4 client renewals are not allowed"

grep -q 'udp sport 547 udp dport 546 accept' packaging/nftables/obos.nft \
  || fail "DHCPv6 client renewals are not allowed"

! grep -q 'tcp dport 22 accept' packaging/nftables/obos.nft \
  || fail "SSH is open in the default firewall"

# shellcheck disable=SC2016
grep -Fq 'DISABLE_SSH="${OBOS_DISABLE_SSH:-1}"' scripts/hardening/apply-host-hardening.sh \
  || fail "SSH disablement is not the default hardening behavior"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing NoNewPrivileges"

grep -q 'ProtectSystem=full' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing filesystem protection"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-openbridgeserver.service \
  || fail "Open Bridge Server systemd unit is missing NoNewPrivileges"

grep -q 'ProtectSystem=full' packaging/systemd/obos-openbridgeserver.service \
  || fail "Open Bridge Server systemd unit is missing filesystem protection"

grep -q 'ssl_certificate /etc/obos/tls/obos.local.crt;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not use obos TLS certificate"

grep -q 'proxy_pass http://127.0.0.1:8080;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not target localhost OBS"

grep -q 'no-new-privileges:true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not set no-new-privileges"

grep -q 'init: true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not enable init process handling"

grep -q 'TLS_DIR=' scripts/obosctl \
  || fail "obosctl backup does not know the TLS material directory"

grep -q 'backup includes TLS private key material' scripts/obosctl \
  || fail "obosctl backup does not warn about TLS private key material"

grep -q 'mqtt-enable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN enablement"

grep -q 'mqtt-disable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN disablement"

grep -q 'basicConstraints=critical,CA:TRUE,pathlen:0' scripts/tls/generate-tls-material.sh \
  || fail "local CA is not generated with critical CA constraints"

grep -q 'No private keys were exported.' scripts/tls/export-trust-bundle.sh \
  || fail "TLS trust export does not state that private keys are excluded"

grep -q 'tls-export)' scripts/obosctl \
  || fail "obosctl does not expose TLS trust export"
