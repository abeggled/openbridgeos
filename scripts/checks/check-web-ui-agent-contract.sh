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
require_contract_line 'sudo obosctl update-rollback-plan'
require_contract_line 'obos-update-rollback-plan-v1'
require_contract_line 'obosctl backup-summary'
require_contract_line 'obos-backup-summary-v1'
require_contract_line 'obosctl backup-list'
require_contract_line 'obos-backup-list-v1'
require_contract_line 'obosctl backup-prune-plan'
require_contract_line 'obos-backup-prune-plan-v1'
require_contract_line 'sudo obosctl backup-prune --confirm backup-prune'
require_contract_line 'obos-agent backup-prune --confirm backup-prune'
require_contract_line 'obos-agent restore-stage <backup.tar.gz> --confirm restore-stage'
require_contract_line 'sudo obosctl restore-stage-summary'
require_contract_line 'obos-restore-stage-summary-v1'
require_contract_line 'obos-agent restore-stage-inspect <stage-dir>'
require_contract_line 'obos-agent restore-apply-plan <stage-dir>'
require_contract_line 'sudo obosctl mqtt-summary'
require_contract_line 'obos-mqtt-summary-v1'
require_contract_line 'obosctl tls-summary'
require_contract_line 'obos-tls-summary-v1'
require_contract_line 'sudo obosctl security-summary'
require_contract_line 'obos-security-baseline-summary-v1'
require_contract_line 'sudo obosctl agent-audit-summary'
require_contract_line 'obos-agent-audit-summary-v1'
require_contract_line 'obos-agent actions'
require_contract_line 'obos-agent-actions-v1'
require_contract_line 'obos-agent update-rollback-plan'
require_contract_line 'obos-agent backup-summary'
require_contract_line 'obos-agent backup-prune-plan'
require_contract_line 'obos-agent restore-stage-summary'
require_contract_line 'obos-agent agent-audit-summary'
require_contract_line 'latest-backup inspection status'
require_contract_line 'obos-agent start --confirm start'
require_contract_line 'obos-agent mqtt-enable-lan [source-cidr] --confirm mqtt-enable-lan'
require_contract_line '/etc/sudoers.d/obos-agent'
require_contract_line 'sudo -n'
require_contract_line 'obos-agent-audit-v1'
require_contract_line 'rotated by logrotate'
require_contract_line 'Optional MQTT source CIDR input is validated by the agent'
require_contract_line 'Restore staging accepts only appliance backup archives below the configured'
require_contract_line 'Restore stage inspection accepts only private restore staging directories'
require_contract_line 'Restore apply planning uses the same stage path validation'

grep -q 'status-summary)' scripts/obosctl \
  || fail "obosctl status-summary command missing"
grep -q 'update-summary)' scripts/obosctl \
  || fail "obosctl update-summary command missing"
grep -q 'update-rollback-plan)' scripts/obosctl \
  || fail "obosctl update-rollback-plan command missing"
grep -q 'backup-summary)' scripts/obosctl \
  || fail "obosctl backup-summary command missing"
grep -q 'backup-list)' scripts/obosctl \
  || fail "obosctl backup-list command missing"
grep -q 'backup-prune-plan)' scripts/obosctl \
  || fail "obosctl backup-prune-plan command missing"
grep -q 'backup-prune)' scripts/obosctl \
  || fail "obosctl backup-prune command missing"
grep -q 'restore-stage-summary)' scripts/obosctl \
  || fail "obosctl restore-stage-summary command missing"
grep -q 'mqtt-summary)' scripts/obosctl \
  || fail "obosctl mqtt-summary command missing"
grep -q 'tls-summary)' scripts/obosctl \
  || fail "obosctl tls-summary command missing"
grep -q 'security-summary)' scripts/obosctl \
  || fail "obosctl security-summary command missing"
grep -q 'agent-audit-summary)' scripts/obosctl \
  || fail "obosctl agent-audit-summary command missing"

echo "web UI agent contract: PASS"
