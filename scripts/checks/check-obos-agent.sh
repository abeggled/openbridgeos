#!/usr/bin/env sh
set -eu

AGENT="scripts/agent/obos-agent.sh"

fail() {
  echo "obos-agent check failed: $1" >&2
  exit 1
}

[ -f "${AGENT}" ] || fail "agent script missing"

grep -q 'format=obos-agent-response-v1' "${AGENT}" \
  || fail "agent response format missing"
grep -q 'format=obos-agent-actions-v1' "${AGENT}" \
  || fail "agent actions format missing"
grep -q 'format=obos-agent-audit-v1' "${AGENT}" \
  || fail "agent audit format missing"
grep -q 'OBOS_AGENT_AUDIT_LOG' "${AGENT}" \
  || fail "agent audit log path is not configurable"
grep -q 'write_audit_log' "${AGENT}" \
  || fail "agent does not write mutation audit entries"
grep -q 'require_no_extra_args' "${AGENT}" \
  || fail "agent does not reject extra arguments"
grep -q 'require_confirm_args' "${AGENT}" \
  || fail "agent does not require confirmation for mutating actions"
grep -q 'require_mqtt_enable_args' "${AGENT}" \
  || fail "agent does not validate MQTT enable arguments"
# shellcheck disable=SC2016
grep -q 'timeout "${timeout_seconds}"' "${AGENT}" \
  || fail "agent does not enforce command timeout"
grep -q 'status-summary)' "${AGENT}" \
  || fail "status-summary action missing"
grep -q 'action=status-summary|mutating=false' "${AGENT}" \
  || fail "status-summary action is not listed as read-only"
grep -q 'update-summary)' "${AGENT}" \
  || fail "update-summary action missing"
grep -q 'backup-list)' "${AGENT}" \
  || fail "backup-list action missing"
grep -q 'mqtt-summary)' "${AGENT}" \
  || fail "mqtt-summary action missing"
grep -q 'tls-summary)' "${AGENT}" \
  || fail "tls-summary action missing"
grep -q 'security-summary)' "${AGENT}" \
  || fail "security-summary action missing"
grep -q 'start)' "${AGENT}" \
  || fail "start action missing"
grep -q 'action=start|mutating=true|confirm=start' "${AGENT}" \
  || fail "start action is not listed as a confirmed mutation"
grep -q 'action=mqtt-enable-lan|mutating=true|confirm=mqtt-enable-lan|optional_arg=source-cidr' "${AGENT}" \
  || fail "MQTT enable action is not listed with source CIDR"
# shellcheck disable=SC2016
grep -q 'install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent.sh" /usr/bin/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "agent is not installed during provisioning"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

cat > "${tmp_dir}/obosctl" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  status-summary)
    echo "format=obos-status-summary-v1"
    exit 0
    ;;
  start)
    echo "started"
    exit 0
    ;;
  mqtt-enable-lan)
    echo "mqtt-enabled:${2:-any}"
    exit 0
    ;;
  *)
    echo "unexpected action: $1" >&2
    exit 2
    ;;
esac
EOF
chmod 0755 "${tmp_dir}/obosctl"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" status-summary |
  grep -q 'format=obos-agent-response-v1' \
  || fail "agent smoke test did not print response format"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" status-summary |
  grep -q 'stdout=format=obos-status-summary-v1' \
  || fail "agent smoke test did not wrap command stdout"

sh "${AGENT}" actions |
  grep -q 'format=obos-agent-actions-v1' \
  || fail "agent actions did not print action format"

if OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" status-summary unexpected >/dev/null 2>&1; then
  fail "agent accepted unexpected extra argument"
fi

if OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" start >/dev/null 2>&1; then
  fail "agent accepted mutation without confirmation"
fi

[ -f "${tmp_dir}/agent-audit.log" ] \
  && fail "read-only calls unexpectedly created audit log before configured mutation"

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" start --confirm start |
  grep -q 'stdout=started' \
  || fail "agent did not run confirmed start mutation"

grep -q 'format=obos-agent-audit-v1|.*|action=start|exit_code=0|timed_out=false' "${tmp_dir}/agent-audit.log" \
  || fail "agent did not write expected mutation audit entry"

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mqtt-enable-lan 192.168.1.0/24 --confirm mqtt-enable-lan |
  grep -q 'stdout=mqtt-enabled:192.168.1.0/24' \
  || fail "agent did not forward MQTT source CIDR"

echo "obos-agent: PASS"
