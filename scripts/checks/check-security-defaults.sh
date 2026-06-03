#!/usr/bin/env sh
set -eu

fail() {
  echo "security check failed: $1" >&2
  exit 1
}

! grep -R "changeme\|password123\|secret123" apps scripts packaging docs README.md SECURITY.md >/dev/null 2>&1 \
  || fail "default placeholder secret found"

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

grep -q '"no-new-privileges": true' packaging/docker/daemon.json \
  || fail "Docker no-new-privileges default is not enabled"

grep -q '"log-driver": "local"' packaging/docker/daemon.json \
  || fail "Docker local log driver is not configured"

grep -q 'policy drop' packaging/nftables/obos.nft \
  || fail "nftables input policy is not default-drop"

grep -q 'tcp dport 8080 accept' packaging/nftables/obos.nft \
  || fail "Open Bridge Server HTTP port is not allowed"

grep -q 'udp sport 67 udp dport 68 accept' packaging/nftables/obos.nft \
  || fail "DHCPv4 client renewals are not allowed"

grep -q 'udp sport 547 udp dport 546 accept' packaging/nftables/obos.nft \
  || fail "DHCPv6 client renewals are not allowed"

! grep -q 'tcp dport 22 accept' packaging/nftables/obos.nft \
  || fail "SSH is open in the default firewall"

grep -q 'DISABLE_SSH="${OBOS_DISABLE_SSH:-1}"' scripts/hardening/apply-host-hardening.sh \
  || fail "SSH disablement is not the default hardening behavior"
