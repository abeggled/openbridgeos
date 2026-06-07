#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
SECURITY_BASELINE="${TMP_DIR}/security-baseline.sh"
SCRIPT="scripts/audit/mvp-runtime-readiness.sh"
mkdir -p "${FAKE_BIN}"

fail() {
  echo "mvp runtime readiness fixture failed: $1" >&2
  exit 1
}

write_fake_command() {
  name="$1"
  body="$2"
  path="${FAKE_BIN}/${name}"
  {
    printf '%s\n' '#!/usr/bin/env sh'
    printf '%s\n' 'set -eu'
    printf '%s\n' "${body}"
  } > "${path}"
  chmod 0755 "${path}"
}

cat > "${SECURITY_BASELINE}" <<'EOF'
#!/usr/bin/env sh
echo "format=obos-security-baseline-summary-v1"
echo "result=PASS"
EOF
chmod 0755 "${SECURITY_BASELINE}"

# shellcheck disable=SC2016
write_fake_command id '[ "${1:-}" = "-u" ] && echo 0 || exit 1'
write_fake_command docker 'exit 0'
write_fake_command nft 'exit 0'
write_fake_command nginx 'exit 0'
write_fake_command gpg 'exit 0'
write_fake_command python3 'exit 0'

# shellcheck disable=SC2016
write_fake_command systemctl '
case "${1:-} ${2:-} ${3:-}" in
  "is-active --quiet docker.service"|"is-active --quiet nginx.service"|"is-active --quiet nftables.service"|"is-active --quiet obos-openbridgeserver.service"|"is-active --quiet obos-agent-http.service") exit 0 ;;
  "is-enabled --quiet docker.service"|"is-enabled --quiet nginx.service"|"is-enabled --quiet nftables.service"|"is-enabled --quiet obos-openbridgeserver.service"|"is-enabled --quiet obos-agent-http.service") exit 0 ;;
  *) exit 1 ;;
esac
'

write_fake_command curl '
echo "format=obos-agent-response-v1"
echo "stdout=format=obos-status-summary-v1"
exit 0
'

# shellcheck disable=SC2016
write_fake_command obosctl '
case "${1:-}" in
  status-summary)
    echo "format=obos-status-summary-v1"
    echo "health_local=ok"
    echo "health_https_proxy=ok"
    ;;
  system-summary) echo "format=obos-system-summary-v1" ;;
  update-summary)
    echo "format=obos-update-summary-v1"
    echo "last_update_present=false"
    ;;
  update-rollback-plan) echo "format=obos-update-rollback-plan-v1" ;;
  backup-summary) echo "format=obos-backup-summary-v1" ;;
  backup-list) echo "format=obos-backup-list-v1" ;;
  logs-summary) echo "format=obos-logs-summary-v1" ;;
  restore-stage-summary) echo "format=obos-restore-stage-summary-v1" ;;
  tls-summary)
    echo "format=obos-tls-summary-v1"
    echo "local_ca_present=true"
    echo "leaf_present=true"
    ;;
  tls-renew-leaf-plan) echo "format=obos-tls-leaf-renewal-plan-v1" ;;
  mqtt-summary)
    echo "format=obos-mqtt-summary-v1"
    echo "lan_enabled=false"
    ;;
  security-summary)
    echo "format=obos-security-baseline-summary-v1"
    echo "result=PASS"
    ;;
  agent-audit-summary) echo "format=obos-agent-audit-summary-v1" ;;
  *) exit 1 ;;
esac
'

# shellcheck disable=SC2016
write_fake_command obos-agent '
case "${1:-}" in
  actions)
    echo "format=obos-agent-actions-v1"
    echo "action=portable-export-plan|mutating=false|required_arg=backup-path"
    echo "action=portable-import-plan|mutating=false|required_arg=portable-backup"
    echo "action=restore-apply-plan|mutating=false|required_arg=stage-dir"
    ;;
  *) exit 1 ;;
esac
'

if ! PATH="${FAKE_BIN}:$PATH" \
  OBOSCTL="${FAKE_BIN}/obosctl" \
  OBOS_AGENT="${FAKE_BIN}/obos-agent" \
  OBOS_SECURITY_BASELINE_SCRIPT="${SECURITY_BASELINE}" \
  sh "${SCRIPT}" summary > "${TMP_DIR}/pass.out"; then
  cat "${TMP_DIR}/pass.out" >&2
  fail "valid fake appliance readiness failed"
fi

grep -q '^format=obos-mvp-runtime-readiness-v1$' "${TMP_DIR}/pass.out" \
  || fail "summary format missing"
grep -q '^result=PASS$' "${TMP_DIR}/pass.out" \
  || fail "valid fake appliance did not pass"
grep -q '^fail_count=0$' "${TMP_DIR}/pass.out" \
  || fail "valid fake appliance reported failures"

# shellcheck disable=SC2016
write_fake_command obos-agent '
case "${1:-}" in
  actions)
    echo "format=obos-agent-actions-v1"
    echo "action=portable-export-plan|mutating=false|required_arg=backup-path"
    echo "action=portable-import-plan|mutating=false|required_arg=portable-backup"
    echo "action=restore-apply-plan|mutating=false|required_arg=stage-dir"
    echo "action=restore-apply|mutating=true|confirm=restore-apply|required_arg=stage-dir"
    ;;
  *) exit 1 ;;
esac
'

if PATH="${FAKE_BIN}:$PATH" \
  OBOSCTL="${FAKE_BIN}/obosctl" \
  OBOS_AGENT="${FAKE_BIN}/obos-agent" \
  OBOS_SECURITY_BASELINE_SCRIPT="${SECURITY_BASELINE}" \
  sh "${SCRIPT}" summary > "${TMP_DIR}/fail.out" 2>/dev/null; then
  fail "runtime readiness accepted restore apply mutation exposure"
fi
grep -q '^result=FAIL$' "${TMP_DIR}/fail.out" \
  || fail "restore apply mutation exposure did not produce FAIL summary"

echo "mvp runtime readiness fixture: PASS"
