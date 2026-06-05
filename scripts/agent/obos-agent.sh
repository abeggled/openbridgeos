#!/usr/bin/env sh
set -eu

OBOSCTL="${OBOS_AGENT_OBOSCTL:-/usr/bin/obosctl}"
TIMEOUT_SECONDS="${OBOS_AGENT_TIMEOUT_SECONDS:-30}"
MUTATION_TIMEOUT_SECONDS="${OBOS_AGENT_MUTATION_TIMEOUT_SECONDS:-600}"
AGENT_AUDIT_LOG="${OBOS_AGENT_AUDIT_LOG:-/srv/obos/state/agent/obos-agent-audit.log}"

usage() {
  cat <<'EOF'
Usage: obos-agent <action>

Read-only actions:
  actions
  status-summary
  update-summary
  update-rollback-plan
  backup-summary
  backup-list
  backup-prune-plan
  mqtt-summary
  tls-summary
  security-summary

Mutating actions:
  start --confirm start
  stop --confirm stop
  restart --confirm restart
  update --confirm update
  backup --confirm backup
  backup-prune --confirm backup-prune
  tls-generate --confirm tls-generate
  tls-export --confirm tls-export
  mqtt-enable-lan [source-cidr] --confirm mqtt-enable-lan
  mqtt-disable-lan --confirm mqtt-disable-lan
EOF
}

fail() {
  echo "obos-agent failed: $1" >&2
  exit 1
}

require_timeout() {
  command -v timeout >/dev/null 2>&1 || fail "timeout command missing"
}

require_no_extra_args() {
  action="$1"
  [ "$#" -eq 1 ] || fail "${action} does not accept arguments"
}

require_confirm_args() {
  action="$1"
  [ "$#" -eq 3 ] || fail "${action} requires: --confirm ${action}"
  [ "${2:-}" = "--confirm" ] || fail "${action} requires: --confirm ${action}"
  [ "${3:-}" = "${action}" ] || fail "${action} confirmation token mismatch"
}

is_ipv4_cidr() {
  # shellcheck disable=SC2016
  printf '%s\n' "$1" | awk -F '[./]' '
    NF != 5 { exit 1 }
    $5 !~ /^[0-9]+$/ || $5 < 0 || $5 > 32 { exit 1 }
    {
      for (i = 1; i <= 4; i++) {
        if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) {
          exit 1
        }
      }
      exit 0
    }
  '
}

validate_source_cidr() {
  source_cidr="$1"
  [ -n "${source_cidr}" ] || return 0

  if is_ipv4_cidr "${source_cidr}"; then
    return 0
  fi

  if printf '%s\n' "${source_cidr}" | grep -Eq '^[0-9A-Fa-f:]+/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])$'; then
    return 0
  fi

  fail "mqtt-enable-lan source CIDR is invalid"
}

require_mqtt_enable_args() {
  action="$1"
  case "$#" in
    3)
      [ "${2:-}" = "--confirm" ] || fail "${action} requires: [source-cidr] --confirm ${action}"
      [ "${3:-}" = "${action}" ] || fail "${action} confirmation token mismatch"
      MQTT_SOURCE_CIDR=
      ;;
    4)
      [ "${3:-}" = "--confirm" ] || fail "${action} requires: [source-cidr] --confirm ${action}"
      [ "${4:-}" = "${action}" ] || fail "${action} confirmation token mismatch"
      MQTT_SOURCE_CIDR="${2:-}"
      case "${MQTT_SOURCE_CIDR}" in
        ""|-*) fail "${action} source CIDR is invalid" ;;
      esac
      validate_source_cidr "${MQTT_SOURCE_CIDR}"
      ;;
    *)
      fail "${action} requires: [source-cidr] --confirm ${action}"
      ;;
  esac
}

print_actions() {
  cat <<'EOF'
format=obos-agent-actions-v1
action=actions|mutating=false
action=status-summary|mutating=false
action=update-summary|mutating=false
action=update-rollback-plan|mutating=false
action=backup-summary|mutating=false
action=backup-list|mutating=false
action=backup-prune-plan|mutating=false
action=backup-prune|mutating=true|confirm=backup-prune
action=mqtt-summary|mutating=false
action=tls-summary|mutating=false
action=security-summary|mutating=false
action=start|mutating=true|confirm=start
action=stop|mutating=true|confirm=stop
action=restart|mutating=true|confirm=restart
action=update|mutating=true|confirm=update
action=backup|mutating=true|confirm=backup
action=tls-generate|mutating=true|confirm=tls-generate
action=tls-export|mutating=true|confirm=tls-export
action=mqtt-enable-lan|mutating=true|confirm=mqtt-enable-lan|optional_arg=source-cidr
action=mqtt-disable-lan|mutating=true|confirm=mqtt-disable-lan
EOF
}

write_audit_log() {
  action="$1"
  exit_code="$2"
  timed_out="$3"
  audit_dir="$(dirname -- "${AGENT_AUDIT_LOG}")"
  created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  install -d -m 0750 "${audit_dir}" 2>/dev/null || mkdir -p "${audit_dir}"
  printf 'format=obos-agent-audit-v1|created_at=%s|action=%s|exit_code=%s|timed_out=%s\n' \
    "${created_at}" "${action}" "${exit_code}" "${timed_out}" >> "${AGENT_AUDIT_LOG}"
  chmod 0640 "${AGENT_AUDIT_LOG}" 2>/dev/null || true
}

run_allowed() {
  action="$1"
  timeout_seconds="$2"
  mutating="$3"
  shift 3
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  exit_code=0
  timed_out=false

  if timeout "${timeout_seconds}" "$@" > "${stdout_file}" 2> "${stderr_file}"; then
    exit_code=0
  else
    exit_code=$?
    if [ "${exit_code}" -eq 124 ]; then
      timed_out=true
    fi
  fi

  if [ "${mutating}" = true ]; then
    write_audit_log "${action}" "${exit_code}" "${timed_out}"
  fi

  cat <<EOF
format=obos-agent-response-v1
action=${action}
exit_code=${exit_code}
timed_out=${timed_out}
stdout_begin
EOF
  sed 's/^/stdout=/' "${stdout_file}"
  cat <<'EOF'
stdout_end
stderr_begin
EOF
  sed 's/^/stderr=/' "${stderr_file}"
  cat <<'EOF'
stderr_end
EOF

  rm -f "${stdout_file}" "${stderr_file}"
  return "${exit_code}"
}

run_obosctl() {
  action="$1"
  timeout_seconds="$2"
  mutating="$3"
  shift 3

  if [ -n "${OBOS_AGENT_OBOSCTL:-}" ]; then
    run_allowed "${action}" "${timeout_seconds}" "${mutating}" "${OBOSCTL}" "$@"
  else
    run_allowed "${action}" "${timeout_seconds}" "${mutating}" sudo -n "${OBOSCTL}" "$@"
  fi
}

require_timeout

case "${1:-}" in
  actions)
    require_no_extra_args "$@"
    print_actions
    ;;
  status-summary)
    require_no_extra_args "$@"
    run_obosctl status-summary "${TIMEOUT_SECONDS}" false status-summary
    ;;
  update-summary)
    require_no_extra_args "$@"
    run_obosctl update-summary "${TIMEOUT_SECONDS}" false update-summary
    ;;
  update-rollback-plan)
    require_no_extra_args "$@"
    run_obosctl update-rollback-plan "${TIMEOUT_SECONDS}" false update-rollback-plan
    ;;
  backup-summary)
    require_no_extra_args "$@"
    run_obosctl backup-summary "${TIMEOUT_SECONDS}" false backup-summary
    ;;
  backup-list)
    require_no_extra_args "$@"
    run_obosctl backup-list "${TIMEOUT_SECONDS}" false backup-list
    ;;
  backup-prune-plan)
    require_no_extra_args "$@"
    run_obosctl backup-prune-plan "${TIMEOUT_SECONDS}" false backup-prune-plan
    ;;
  backup-prune)
    require_confirm_args "$@"
    run_obosctl backup-prune "${MUTATION_TIMEOUT_SECONDS}" true backup-prune --confirm backup-prune
    ;;
  mqtt-summary)
    require_no_extra_args "$@"
    run_obosctl mqtt-summary "${TIMEOUT_SECONDS}" false mqtt-summary
    ;;
  tls-summary)
    require_no_extra_args "$@"
    run_obosctl tls-summary "${TIMEOUT_SECONDS}" false tls-summary
    ;;
  security-summary)
    require_no_extra_args "$@"
    run_obosctl security-summary "${TIMEOUT_SECONDS}" false security-summary
    ;;
  start)
    require_confirm_args "$@"
    run_obosctl start "${MUTATION_TIMEOUT_SECONDS}" true start
    ;;
  stop)
    require_confirm_args "$@"
    run_obosctl stop "${MUTATION_TIMEOUT_SECONDS}" true stop
    ;;
  restart)
    require_confirm_args "$@"
    run_obosctl restart "${MUTATION_TIMEOUT_SECONDS}" true restart
    ;;
  update)
    require_confirm_args "$@"
    run_obosctl update "${MUTATION_TIMEOUT_SECONDS}" true update
    ;;
  backup)
    require_confirm_args "$@"
    run_obosctl backup "${MUTATION_TIMEOUT_SECONDS}" true backup
    ;;
  tls-generate)
    require_confirm_args "$@"
    run_obosctl tls-generate "${MUTATION_TIMEOUT_SECONDS}" true tls-generate
    ;;
  tls-export)
    require_confirm_args "$@"
    run_obosctl tls-export "${MUTATION_TIMEOUT_SECONDS}" true tls-export
    ;;
  mqtt-enable-lan)
    require_mqtt_enable_args "$@"
    if [ -n "${MQTT_SOURCE_CIDR}" ]; then
      run_obosctl mqtt-enable-lan "${MUTATION_TIMEOUT_SECONDS}" true mqtt-enable-lan "${MQTT_SOURCE_CIDR}"
    else
      run_obosctl mqtt-enable-lan "${MUTATION_TIMEOUT_SECONDS}" true mqtt-enable-lan
    fi
    ;;
  mqtt-disable-lan)
    require_confirm_args "$@"
    run_obosctl mqtt-disable-lan "${MUTATION_TIMEOUT_SECONDS}" true mqtt-disable-lan
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
