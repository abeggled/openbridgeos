#!/usr/bin/env sh
set -eu

OBOSCTL="${OBOS_AGENT_OBOSCTL:-obosctl}"
TIMEOUT_SECONDS="${OBOS_AGENT_TIMEOUT_SECONDS:-30}"
MUTATION_TIMEOUT_SECONDS="${OBOS_AGENT_MUTATION_TIMEOUT_SECONDS:-600}"

usage() {
  cat <<'EOF'
Usage: obos-agent <action>

Read-only actions:
  actions
  status-summary
  update-summary
  backup-list
  mqtt-summary
  tls-summary
  security-summary

Mutating actions:
  start --confirm start
  stop --confirm stop
  restart --confirm restart
  update --confirm update
  backup --confirm backup
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
action=backup-list|mutating=false
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

run_allowed() {
  action="$1"
  timeout_seconds="$2"
  shift 2
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

require_timeout

case "${1:-}" in
  actions)
    require_no_extra_args "$@"
    print_actions
    ;;
  status-summary)
    require_no_extra_args "$@"
    run_allowed status-summary "${TIMEOUT_SECONDS}" "${OBOSCTL}" status-summary
    ;;
  update-summary)
    require_no_extra_args "$@"
    run_allowed update-summary "${TIMEOUT_SECONDS}" "${OBOSCTL}" update-summary
    ;;
  backup-list)
    require_no_extra_args "$@"
    run_allowed backup-list "${TIMEOUT_SECONDS}" "${OBOSCTL}" backup-list
    ;;
  mqtt-summary)
    require_no_extra_args "$@"
    run_allowed mqtt-summary "${TIMEOUT_SECONDS}" "${OBOSCTL}" mqtt-summary
    ;;
  tls-summary)
    require_no_extra_args "$@"
    run_allowed tls-summary "${TIMEOUT_SECONDS}" "${OBOSCTL}" tls-summary
    ;;
  security-summary)
    require_no_extra_args "$@"
    run_allowed security-summary "${TIMEOUT_SECONDS}" "${OBOSCTL}" security-summary
    ;;
  start)
    require_confirm_args "$@"
    run_allowed start "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" start
    ;;
  stop)
    require_confirm_args "$@"
    run_allowed stop "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" stop
    ;;
  restart)
    require_confirm_args "$@"
    run_allowed restart "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" restart
    ;;
  update)
    require_confirm_args "$@"
    run_allowed update "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" update
    ;;
  backup)
    require_confirm_args "$@"
    run_allowed backup "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" backup
    ;;
  tls-generate)
    require_confirm_args "$@"
    run_allowed tls-generate "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" tls-generate
    ;;
  tls-export)
    require_confirm_args "$@"
    run_allowed tls-export "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" tls-export
    ;;
  mqtt-enable-lan)
    require_mqtt_enable_args "$@"
    if [ -n "${MQTT_SOURCE_CIDR}" ]; then
      run_allowed mqtt-enable-lan "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" mqtt-enable-lan "${MQTT_SOURCE_CIDR}"
    else
      run_allowed mqtt-enable-lan "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" mqtt-enable-lan
    fi
    ;;
  mqtt-disable-lan)
    require_confirm_args "$@"
    run_allowed mqtt-disable-lan "${MUTATION_TIMEOUT_SECONDS}" "${OBOSCTL}" mqtt-disable-lan
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
