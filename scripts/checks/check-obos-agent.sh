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
grep -q 'timeout "${TIMEOUT_SECONDS}"' "${AGENT}" \
  || fail "agent does not enforce command timeout"
grep -q 'status-summary)' "${AGENT}" \
  || fail "status-summary action missing"
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

echo "obos-agent: PASS"
