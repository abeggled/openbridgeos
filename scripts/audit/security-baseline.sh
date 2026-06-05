#!/usr/bin/env sh
set -u

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
SUMMARY_MODE=0
APP_NAME="openbridgeserver"
ENV_FILE="${OBOS_ENV_FILE:-/etc/obos/apps/${APP_NAME}.env}"
APP_DIR="${OBOS_APP_DIR:-/srv/obos/apps/${APP_NAME}}"
TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
APPLIANCE_ID_FILE="${OBOS_APPLIANCE_ID_FILE:-/etc/obos/appliance-id}"
HEALTH_URL="${OBOS_HEALTH_URL:-http://127.0.0.1:8080/api/v1/system/health}"
PROXY_HEALTH_HOST="${OBOS_PROXY_HEALTH_HOST:-obos.local}"
PROXY_HEALTH_URL="${OBOS_PROXY_HEALTH_URL:-https://${PROXY_HEALTH_HOST}/api/v1/system/health}"
AGENT_HTTP_URL="${OBOS_AGENT_HTTP_URL:-http://127.0.0.1:8091/obos/api/v1/actions/status-summary}"
TLS_CA_CERT="${OBOS_TLS_CA_CERT:-${TLS_DIR}/obos-local-ca.crt}"
NGINX_PROXY_CONF="${OBOS_NGINX_PROXY_CONF:-/etc/nginx/sites-available/obos-openbridgeserver.conf}"
AGENT_AUDIT_DIR="${OBOS_AGENT_AUDIT_DIR:-${STATE_DIR}/agent}"
AGENT_AUDIT_LOG="${OBOS_AGENT_AUDIT_LOG:-${AGENT_AUDIT_DIR}/obos-agent-audit.log}"
AGENT_SUDOERS="${OBOS_AGENT_SUDOERS:-/etc/sudoers.d/obos-agent}"
AGENT_LOGROTATE="${OBOS_AGENT_LOGROTATE:-/etc/logrotate.d/obos-agent}"

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  if [ "${SUMMARY_MODE}" -ne 1 ]; then
    printf 'PASS %s\n' "$1"
  fi
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  if [ "${SUMMARY_MODE}" -ne 1 ]; then
    printf 'FAIL %s\n' "$1"
  fi
  FAILED=1
}

case "${1:-}" in
  summary)
    SUMMARY_MODE=1
    ;;
  -h|--help|help)
    echo "usage: security-baseline.sh [summary]" >&2
    exit 2
    ;;
esac

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

check_optional_file_mode() {
  path="$1"
  expected="$2"
  if [ -e "${path}" ]; then
    check_file_mode "${path}" "${expected}"
  else
    pass "${path} absent"
  fi
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    fail "$1 missing"
  fi
}

check_user() {
  if id -u "$1" >/dev/null 2>&1; then
    pass "$1 user exists"
  else
    fail "$1 user missing"
  fi
}

check_systemd_active() {
  service="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "${service} active not checked because systemctl is missing"
    return
  fi
  if systemctl is-active --quiet "${service}"; then
    pass "${service} active"
  else
    fail "${service} not active"
  fi
}

check_systemd_enabled() {
  service="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "${service} enabled not checked because systemctl is missing"
    return
  fi
  if systemctl is-enabled --quiet "${service}"; then
    pass "${service} enabled"
  else
    fail "${service} not enabled"
  fi
}

check_systemd_property() {
  service="$1"
  property="$2"
  expected="$3"
  label="$4"
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "${service} ${label} not checked because systemctl is missing"
    return
  fi
  actual="$(systemctl show --property="${property}" --value "${service}" 2>/dev/null || true)"
  if [ "${actual}" = "${expected}" ]; then
    pass "${service} ${label}"
  else
    fail "${service} ${label} expected ${expected}, got ${actual:-missing}"
  fi
}

check_obos_systemd_hardening() {
  service="$1"
  check_systemd_property "${service}" UMask 0077 "restrictive umask"
  check_systemd_property "${service}" NoNewPrivileges yes "NoNewPrivileges"
  check_systemd_property "${service}" PrivateTmp yes "PrivateTmp"
  check_systemd_property "${service}" ProtectHome yes "ProtectHome"
  check_systemd_property "${service}" ProtectSystem full "ProtectSystem"
  check_systemd_property "${service}" LockPersonality yes "LockPersonality"
  check_systemd_property "${service}" MemoryDenyWriteExecute yes "MemoryDenyWriteExecute"
  check_systemd_property "${service}" RestrictRealtime yes "RestrictRealtime"
  check_systemd_property "${service}" SystemCallArchitectures native "native system call architecture"
}

check_agent_http_systemd_hardening() {
  service="obos-agent-http.service"
  check_systemd_property "${service}" User obos-agent "service user"
  check_systemd_property "${service}" UMask 0077 "restrictive umask"
  check_systemd_property "${service}" NoNewPrivileges no "sudo-compatible NoNewPrivileges disabled"
  check_systemd_property "${service}" PrivateTmp yes "PrivateTmp"
  check_systemd_property "${service}" ProtectHome yes "ProtectHome"
  check_systemd_property "${service}" ProtectSystem strict "ProtectSystem"
  check_systemd_property "${service}" LockPersonality yes "LockPersonality"
  check_systemd_property "${service}" MemoryDenyWriteExecute yes "MemoryDenyWriteExecute"
  check_systemd_property "${service}" RestrictRealtime yes "RestrictRealtime"
  check_systemd_property "${service}" SystemCallArchitectures native "native system call architecture"
}

check_systemd_not_active() {
  service="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "${service} inactive state not checked because systemctl is missing"
    return
  fi
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
check_command obos-agent
check_command openssl
check_command python3

check_user obos-agent

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
check_file_mode "${AGENT_SUDOERS}" 440
check_file_mode "${AGENT_LOGROTATE}" 644
check_optional_file_mode "${AGENT_AUDIT_DIR}" 750
check_optional_file_mode "${AGENT_AUDIT_LOG}" 640
check_grep 'obos-agent ALL=(root) NOPASSWD:' "${AGENT_SUDOERS}" 'obos-agent sudoers allowlisted root boundary'
check_grep '/usr/bin/obosctl agent-audit-summary' "${AGENT_SUDOERS}" 'obos-agent sudoers audit summary command'
check_grep 'create 0640 obos-agent obos-agent' "${AGENT_LOGROTATE}" 'obos-agent audit logrotate permissions'

check_systemd_active docker.service
check_systemd_enabled docker.service
check_systemd_active nginx.service
check_systemd_enabled nginx.service
check_systemd_active nftables.service
check_systemd_enabled nftables.service
check_systemd_enabled obos-first-boot.service
check_systemd_active obos-agent-http.service
check_systemd_enabled obos-agent-http.service
check_systemd_enabled obos-openbridgeserver.service
check_obos_systemd_hardening obos-first-boot.service
check_agent_http_systemd_hardening
check_obos_systemd_hardening obos-openbridgeserver.service
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
check_grep 'ssl_certificate /etc/obos/tls/obos.local.crt;' "${NGINX_PROXY_CONF}" 'nginx uses obos TLS certificate'
check_grep 'proxy_pass http://127.0.0.1:8080;' "${NGINX_PROXY_CONF}" 'nginx proxies to localhost open bridge server'
check_grep 'location /obos/api/' "${NGINX_PROXY_CONF}" 'nginx exposes obos agent HTTP bridge path'
check_grep 'proxy_pass http://127.0.0.1:8091;' "${NGINX_PROXY_CONF}" 'nginx proxies obos agent HTTP bridge to localhost'
check_grep 'server_tokens off;' "${NGINX_PROXY_CONF}" 'nginx server token disclosure disabled'
check_grep 'client_body_timeout 30s;' "${NGINX_PROXY_CONF}" 'nginx client body timeout bounded'
check_grep 'client_header_timeout 30s;' "${NGINX_PROXY_CONF}" 'nginx client header timeout bounded'
check_grep 'send_timeout 60s;' "${NGINX_PROXY_CONF}" 'nginx send timeout bounded'

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

if command -v curl >/dev/null 2>&1 && curl --fail --silent --show-error --max-time 5 "${AGENT_HTTP_URL}" |
  grep -q 'format=obos-agent-response-v1'; then
  pass 'obos-agent HTTP bridge status endpoint reachable on localhost'
else
  fail 'obos-agent HTTP bridge status endpoint unreachable on localhost'
fi

if [ -d "${APP_DIR}/data" ]; then
  pass 'open bridge server data directory exists'
else
  fail 'open bridge server data directory missing'
fi

if [ "${SUMMARY_MODE}" -eq 1 ]; then
  if [ "${FAILED}" -eq 0 ]; then
    result=PASS
  else
    result=FAIL
  fi
  cat <<EOF
format=obos-security-baseline-summary-v1
result=${result}
pass_count=${PASS_COUNT}
fail_count=${FAIL_COUNT}
EOF
elif [ "${FAILED}" -eq 0 ]; then
  echo 'security baseline: PASS'
else
  echo 'security baseline: FAIL'
fi

exit "${FAILED}"
