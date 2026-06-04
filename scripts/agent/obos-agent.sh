#!/usr/bin/env sh
set -eu

OBOSCTL="${OBOS_AGENT_OBOSCTL:-obosctl}"
TIMEOUT_SECONDS="${OBOS_AGENT_TIMEOUT_SECONDS:-30}"

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
EOF
}

run_allowed() {
  action="$1"
  shift
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  exit_code=0
  timed_out=false

  if timeout "${TIMEOUT_SECONDS}" "$@" > "${stdout_file}" 2> "${stderr_file}"; then
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
    run_allowed status-summary "${OBOSCTL}" status-summary
    ;;
  update-summary)
    require_no_extra_args "$@"
    run_allowed update-summary "${OBOSCTL}" update-summary
    ;;
  backup-list)
    require_no_extra_args "$@"
    run_allowed backup-list "${OBOSCTL}" backup-list
    ;;
  mqtt-summary)
    require_no_extra_args "$@"
    run_allowed mqtt-summary "${OBOSCTL}" mqtt-summary
    ;;
  tls-summary)
    require_no_extra_args "$@"
    run_allowed tls-summary "${OBOSCTL}" tls-summary
    ;;
  security-summary)
    require_no_extra_args "$@"
    run_allowed security-summary "${OBOSCTL}" security-summary
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
