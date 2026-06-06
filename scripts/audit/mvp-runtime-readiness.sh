#!/usr/bin/env sh
set -u

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
SUMMARY_MODE=0
OBOSCTL="${OBOSCTL:-/usr/bin/obosctl}"
OBOS_AGENT="${OBOS_AGENT:-/usr/bin/obos-agent}"
SECURITY_BASELINE_SCRIPT="${OBOS_SECURITY_BASELINE_SCRIPT:-/usr/lib/obos/security-baseline.sh}"
AGENT_HTTP_URL="${OBOS_AGENT_HTTP_URL:-http://127.0.0.1:8091/obos/api/v1/actions/status-summary}"

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
    echo "usage: mvp-runtime-readiness.sh [summary]" >&2
    exit 2
    ;;
esac

check_root() {
  if [ "$(id -u)" -eq 0 ]; then
    pass "running as root"
  else
    fail "must run as root for complete appliance readiness checks"
  fi
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    fail "$1 missing"
  fi
}

check_file_executable() {
  path="$1"
  if [ -x "${path}" ]; then
    pass "${path} executable"
  else
    fail "${path} missing or not executable"
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

check_output_contains() {
  label="$1"
  expected="$2"
  shift 2
  output="$("$@" 2>/dev/null)"
  exit_code=$?
  if [ "${exit_code}" -eq 0 ] && printf '%s\n' "${output}" | grep -Fq "${expected}"; then
    pass "${label}"
  else
    fail "${label}"
  fi
}

check_output_not_contains_line() {
  label="$1"
  pattern="$2"
  shift 2
  output="$("$@" 2>/dev/null)"
  exit_code=$?
  if [ "${exit_code}" -ne 0 ]; then
    fail "${label}"
    return
  fi
  if printf '%s\n' "${output}" | grep -Eq "${pattern}"; then
    fail "${label}"
  else
    pass "${label}"
  fi
}

check_summary_format() {
  label="$1"
  expected_format="$2"
  shift 2
  check_output_contains "${label}" "format=${expected_format}" "$@"
}

check_http_agent_status() {
  if command -v curl >/dev/null 2>&1; then
    output="$(curl --fail --silent --show-error --max-time 5 "${AGENT_HTTP_URL}" 2>/dev/null)"
    exit_code=$?
  else
    output=
    exit_code=1
  fi

  if [ "${exit_code}" -eq 0 ] &&
    printf '%s\n' "${output}" | grep -Fq 'format=obos-agent-response-v1' &&
    printf '%s\n' "${output}" | grep -Fq 'stdout=format=obos-status-summary-v1'; then
    pass "obos-agent HTTP bridge returns appliance status"
  else
    fail "obos-agent HTTP bridge does not return appliance status"
  fi
}

check_update_rollback_plan_if_available() {
  output="$("${OBOSCTL}" update-summary 2>/dev/null)"
  exit_code=$?
  if [ "${exit_code}" -ne 0 ]; then
    fail "update summary available for rollback gating"
    return
  fi

  if printf '%s\n' "${output}" | grep -Fq 'last_update_present=true'; then
    check_summary_format "update rollback plan available for last update" obos-update-rollback-plan-v1 "${OBOSCTL}" update-rollback-plan
  elif printf '%s\n' "${output}" | grep -Fq 'last_update_present=false'; then
    pass "update rollback plan skipped until first successful update"
  else
    fail "update summary last update marker present"
  fi
}

check_root

check_command docker
check_command nft
check_command nginx
check_command curl
check_command gpg
check_command python3
check_command obosctl
check_command obos-agent

check_file_executable "${SECURITY_BASELINE_SCRIPT}"

check_systemd_active docker.service
check_systemd_enabled docker.service
check_systemd_active nginx.service
check_systemd_enabled nginx.service
check_systemd_active nftables.service
check_systemd_enabled nftables.service
check_systemd_active obos-openbridgeserver.service
check_systemd_enabled obos-openbridgeserver.service
check_systemd_active obos-agent-http.service
check_systemd_enabled obos-agent-http.service

check_summary_format "status summary format available" obos-status-summary-v1 "${OBOSCTL}" status-summary
check_output_contains "localhost open bridge server health passes" "health_local=ok" "${OBOSCTL}" status-summary
check_output_contains "verified HTTPS proxy health passes" "health_https_proxy=ok" "${OBOSCTL}" status-summary
check_summary_format "system summary format available" obos-system-summary-v1 "${OBOSCTL}" system-summary
check_summary_format "update summary format available" obos-update-summary-v1 "${OBOSCTL}" update-summary
check_update_rollback_plan_if_available
check_summary_format "backup summary format available" obos-backup-summary-v1 "${OBOSCTL}" backup-summary
check_summary_format "backup inventory format available" obos-backup-list-v1 "${OBOSCTL}" backup-list
check_summary_format "logs summary format available" obos-logs-summary-v1 "${OBOSCTL}" logs-summary
check_summary_format "restore stage summary format available" obos-restore-stage-summary-v1 "${OBOSCTL}" restore-stage-summary
check_summary_format "TLS summary format available" obos-tls-summary-v1 "${OBOSCTL}" tls-summary
check_output_contains "TLS local CA present" "local_ca_present=true" "${OBOSCTL}" tls-summary
check_output_contains "TLS leaf certificate present" "leaf_present=true" "${OBOSCTL}" tls-summary
check_summary_format "TLS leaf renewal plan available" obos-tls-leaf-renewal-plan-v1 "${OBOSCTL}" tls-renew-leaf-plan
check_summary_format "MQTT summary format available" obos-mqtt-summary-v1 "${OBOSCTL}" mqtt-summary
check_output_contains "MQTT LAN access disabled by default" "lan_enabled=false" "${OBOSCTL}" mqtt-summary
check_summary_format "security baseline summary format available" obos-security-baseline-summary-v1 "${OBOSCTL}" security-summary
check_output_contains "security baseline passes" "result=PASS" "${OBOSCTL}" security-summary
check_summary_format "agent audit summary format available" obos-agent-audit-summary-v1 "${OBOSCTL}" agent-audit-summary

check_summary_format "obos-agent action inventory available" obos-agent-actions-v1 "${OBOS_AGENT}" actions
check_output_contains "agent exposes portable export planning" "action=portable-export-plan|mutating=false|required_arg=backup-path" "${OBOS_AGENT}" actions
check_output_contains "agent exposes portable import planning" "action=portable-import-plan|mutating=false|required_arg=portable-backup" "${OBOS_AGENT}" actions
check_output_contains "agent exposes restore apply planning only" "action=restore-apply-plan|mutating=false|required_arg=stage-dir" "${OBOS_AGENT}" actions
check_output_not_contains_line "agent does not expose restore apply mutation" '^action=restore-apply\|' "${OBOS_AGENT}" actions
check_http_agent_status

if [ "${SUMMARY_MODE}" -eq 1 ]; then
  if [ "${FAILED}" -eq 0 ]; then
    result=PASS
  else
    result=FAIL
  fi
  cat <<EOF
format=obos-mvp-runtime-readiness-v1
result=${result}
pass_count=${PASS_COUNT}
fail_count=${FAIL_COUNT}
EOF
elif [ "${FAILED}" -eq 0 ]; then
  echo 'mvp runtime readiness: PASS'
else
  echo 'mvp runtime readiness: FAIL'
fi

exit "${FAILED}"
