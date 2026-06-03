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

grep -q 'OBS_JWT_SECRET=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "OBS JWT secret is not generated on first boot"

grep -q 'OBS_MQTT_PASSWORD=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "MQTT password is not generated on first boot"
