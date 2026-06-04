#!/usr/bin/env sh
set -eu

CONTRACT="docs/web-ui-agent-contract.md"

fail() {
  echo "web UI agent contract check failed: $1" >&2
  exit 1
}

require_contract_line() {
  expected="$1"
  grep -Fq "${expected}" "${CONTRACT}" \
    || fail "missing contract line: ${expected}"
}

[ -f "${CONTRACT}" ] || fail "contract document missing: ${CONTRACT}"

require_contract_line 'obosctl status-summary'
require_contract_line 'obos-status-summary-v1'
require_contract_line 'obosctl update-summary'
require_contract_line 'obos-update-summary-v1'
require_contract_line 'obosctl backup-list'
require_contract_line 'obos-backup-list-v1'
require_contract_line 'sudo obosctl mqtt-summary'
require_contract_line 'obos-mqtt-summary-v1'
require_contract_line 'obosctl tls-summary'
require_contract_line 'obos-tls-summary-v1'
require_contract_line 'sudo obosctl security-summary'
require_contract_line 'obos-security-baseline-summary-v1'
require_contract_line 'obos-agent actions'
require_contract_line 'obos-agent-actions-v1'
require_contract_line 'obos-agent start --confirm start'
require_contract_line 'obos-agent mqtt-enable-lan [source-cidr] --confirm mqtt-enable-lan'
require_contract_line '/etc/sudoers.d/obos-agent'
require_contract_line 'sudo -n'
require_contract_line 'obos-agent-audit-v1'

grep -q 'status-summary)' scripts/obosctl \
  || fail "obosctl status-summary command missing"
grep -q 'update-summary)' scripts/obosctl \
  || fail "obosctl update-summary command missing"
grep -q 'backup-list)' scripts/obosctl \
  || fail "obosctl backup-list command missing"
grep -q 'mqtt-summary)' scripts/obosctl \
  || fail "obosctl mqtt-summary command missing"
grep -q 'tls-summary)' scripts/obosctl \
  || fail "obosctl tls-summary command missing"
grep -q 'security-summary)' scripts/obosctl \
  || fail "obosctl security-summary command missing"

echo "web UI agent contract: PASS"
