#!/usr/bin/env sh
set -u

FAILED=0
APP_NAME="openbridgeserver"
ENV_FILE="${OBOS_ENV_FILE:-/etc/obos/apps/${APP_NAME}.env}"
APP_DIR="${OBOS_APP_DIR:-/srv/obos/apps/${APP_NAME}}"
TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
APPLIANCE_ID_FILE="${OBOS_APPLIANCE_ID_FILE:-/etc/obos/appliance-id}"
HEALTH_URL="${OBOS_HEALTH_URL:-http://127.0.0.1:8080/api/v1/system/health}"
PROXY_HEALTH_HOST="${OBOS_PROXY_HEALTH_HOST:-obos.local}"
PROXY_HEALTH_URL="${OBOS_PROXY_HEALTH_URL:-https://${PROXY_HEALTH_HOST}/api/v1/system/health}"
TLS_CA_CERT="${OBOS_TLS_CA_CERT:-${TLS_DIR}/obos-local-ca.crt}"

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1"
  FAILED=1
}

check_file_mode() {
  path="$1"
  expected="$2"
  actual="$(stat -c '%a' "${path}" 2>/dev/null || true)"
  if [ "${actual}" = "${expected}" ]; then
    pass "${path} mode ${expected}"
  else
    fail "${path} mode expected ${expected}, got ${actual:-missing}"
  fi
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    fail "$1 missing"
  fi
}

check_systemd_active() {
  service="$1"
  if systemctl is-active --quiet "${service}"; then
    pass "${service} active"
  else
    fail "${service} not active"
  fi
}

check_systemd_enabled() {
  service="$1"
  if systemctl is-enabled --quiet "${service}"; then
    pass "${service} enabled"
  else
    fail "${service} not enabled"
  fi
}

check_systemd_not_active() {
  service="$1"
  if systemctl list-unit-files "${service}" >/dev/null 2>&1 && systemctl is-active --quiet "${service}"; then
    fail "${service} active"
  else
    pass "${service} not active"
  fi
}

check_grep() {
  pattern="$1"
  file="$2"
  label="$3"
  if grep -q "${pattern}" "${file}" 2>/dev/null; then
    pass "${label}"
  else
    fail "${label}"
  fi
}

check_certificate() {
  cert="$1"
  label="$2"
  if openssl x509 -in "${cert}" -noout >/dev/null 2>&1; then
    pass "${label} certificate parseable"
  else
    fail "${label} certificate not parseable"
  fi
}

check_uuid_file() {
  path="$1"
  label="$2"
  if grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' "${path}" 2>/dev/null; then
    pass "${label} valid UUID"
  else
    fail "${label} missing or invalid UUID"
  fi
}

check_proxy_health() {
  if [ ! -f "${TLS_CA_CERT}" ]; then
    fail "HTTPS reverse proxy local CA missing"
    return
  fi

  if command -v curl >/dev/null 2>&1 && curl --fail --silent --show-error --max-time 5 \
    --cacert "${TLS_CA_CERT}" \
    --resolve "${PROXY_HEALTH_HOST}:443:127.0.0.1" \
    "${PROXY_HEALTH_URL}" >/dev/null; then
    pass 'HTTPS reverse proxy health endpoint reachable with local CA trust'
  else
    fail 'HTTPS reverse proxy health endpoint unreachable with local CA trust'
  fi
}

check_command docker
check_command nft
check_command nginx
check_command obosctl
check_command openssl

check_file_mode /etc/obos 750
check_file_mode "${ENV_FILE}" 600
check_file_mode "${APPLIANCE_ID_FILE}" 644
check_uuid_file "${APPLIANCE_ID_FILE}" 'appliance identifier'
check_file_mode /srv/obos 750
check_file_mode "${TLS_DIR}" 700
check_file_mode "${TLS_DIR}/obos-local-ca.key" 600
check_file_mode "${TLS_DIR}/obos.local.key" 600
check_certificate "${TLS_DIR}/obos-local-ca.crt" 'local CA'
check_certificate "${TLS_DIR}/obos.local.crt" 'leaf'

check_systemd_active docker.service
check_systemd_enabled docker.service
check_systemd_active nginx.service
check_systemd_enabled nginx.service
check_systemd_active nftables.service
check_systemd_enabled nftables.service
check_systemd_enabled obos-first-boot.service
check_systemd_enabled obos-openbridgeserver.service
check_systemd_not_active ssh.service

if nft list ruleset 2>/dev/null | grep -q 'policy drop'; then
  pass 'nftables input default-drop present'
else
  fail 'nftables input default-drop missing'
fi

if nft list ruleset 2>/dev/null | grep -q 'tcp dport 443 accept'; then
  pass 'nftables allows HTTPS reverse proxy'
else
  fail 'nftables missing HTTPS reverse proxy allow rule'
fi

if nft list ruleset 2>/dev/null | grep -q 'tcp dport 8080 accept'; then
  fail 'nftables exposes direct open bridge server HTTP'
else
  pass 'nftables does not expose direct open bridge server HTTP'
fi

if nft list ruleset 2>/dev/null | grep -q 'tcp dport 22 accept'; then
  fail 'nftables exposes SSH'
else
  pass 'nftables does not expose SSH'
fi

check_grep 'OBS_HTTP_HOST_PORT=127.0.0.1:8080' "${ENV_FILE}" 'OBS HTTP localhost-only'
check_grep 'OBS_MQTT_HOST_PORT=127.0.0.1:1883' "${ENV_FILE}" 'MQTT plain localhost-only'
check_grep 'OBS_MQTT_WS_HOST_PORT=127.0.0.1:9001' "${ENV_FILE}" 'MQTT websocket localhost-only'
check_grep '^OBS_JWT_SECRET=.' "${ENV_FILE}" 'OBS JWT secret exists'
check_grep '^OBS_MQTT_PASSWORD=.' "${ENV_FILE}" 'OBS MQTT password exists'

if docker info --format '{{json .SecurityOptions}}' 2>/dev/null | grep -q 'name=no-new-privileges'; then
  pass 'Docker no-new-privileges enabled'
else
  fail 'Docker no-new-privileges missing'
fi

if docker info --format '{{.LoggingDriver}}' 2>/dev/null | grep -q '^local$'; then
  pass 'Docker local log driver enabled'
else
  fail 'Docker local log driver missing'
fi

if command -v curl >/dev/null 2>&1 && curl --fail --silent --show-error --max-time 5 "${HEALTH_URL}" >/dev/null; then
  pass 'open bridge server health endpoint reachable on localhost'
else
  fail 'open bridge server localhost health endpoint unreachable'
fi

check_proxy_health

if [ -d "${APP_DIR}/data" ]; then
  pass 'open bridge server data directory exists'
else
  fail 'open bridge server data directory missing'
fi

if [ "${FAILED}" -eq 0 ]; then
  echo 'security baseline: PASS'
else
  echo 'security baseline: FAIL'
fi

exit "${FAILED}"
