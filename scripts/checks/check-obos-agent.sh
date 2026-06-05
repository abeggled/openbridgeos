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
# shellcheck disable=SC2016
grep -q 'sudo -n "${OBOSCTL}"' "${AGENT}" \
  || fail "agent does not use non-interactive sudo for obosctl"
grep -q 'OBOS_AGENT_OBOSCTL' "${AGENT}" \
  || fail "agent obosctl path is not testable"
grep -q 'require_no_extra_args' "${AGENT}" \
  || fail "agent does not reject extra arguments"
grep -q 'require_confirm_args' "${AGENT}" \
  || fail "agent does not require confirmation for mutating actions"
grep -q 'require_mqtt_enable_args' "${AGENT}" \
  || fail "agent does not validate MQTT enable arguments"
grep -q 'validate_source_cidr' "${AGENT}" \
  || fail "agent does not validate MQTT source CIDR before sudo"
# shellcheck disable=SC2016
grep -q 'timeout "${timeout_seconds}"' "${AGENT}" \
  || fail "agent does not enforce command timeout"
grep -q 'status-summary)' "${AGENT}" \
  || fail "status-summary action missing"
grep -q 'action=status-summary|mutating=false' "${AGENT}" \
  || fail "status-summary action is not listed as read-only"
grep -q 'update-summary)' "${AGENT}" \
  || fail "update-summary action missing"
grep -q 'update-rollback-plan)' "${AGENT}" \
  || fail "update-rollback-plan action missing"
grep -q 'action=update-rollback-plan|mutating=false' "${AGENT}" \
  || fail "update-rollback-plan action is not listed as read-only"
grep -q 'backup-summary)' "${AGENT}" \
  || fail "backup-summary action missing"
grep -q 'action=backup-summary|mutating=false' "${AGENT}" \
  || fail "backup-summary action is not listed as read-only"
grep -q 'backup-list)' "${AGENT}" \
  || fail "backup-list action missing"
grep -q 'backup-prune-plan)' "${AGENT}" \
  || fail "backup-prune-plan action missing"
grep -q 'action=backup-prune-plan|mutating=false' "${AGENT}" \
  || fail "backup-prune-plan action is not listed as read-only"
grep -q 'restore-stage-summary)' "${AGENT}" \
  || fail "restore-stage-summary action missing"
grep -q 'action=restore-stage-summary|mutating=false' "${AGENT}" \
  || fail "restore-stage-summary action is not listed as read-only"
grep -q 'restore-stage-inspect)' "${AGENT}" \
  || fail "restore-stage-inspect action missing"
grep -q 'action=restore-stage-inspect|mutating=false|required_arg=stage-dir' "${AGENT}" \
  || fail "restore-stage-inspect action is not listed as read-only with stage dir"
grep -q 'restore-apply-plan)' "${AGENT}" \
  || fail "restore-apply-plan action missing"
grep -q 'action=restore-apply-plan|mutating=false|required_arg=stage-dir' "${AGENT}" \
  || fail "restore-apply-plan action is not listed as read-only with stage dir"
grep -q 'validate_restore_stage_path' "${AGENT}" \
  || fail "restore-stage-inspect stage path is not validated before sudo"
grep -q 'backup-prune)' "${AGENT}" \
  || fail "backup-prune action missing"
grep -q 'action=backup-prune|mutating=true|confirm=backup-prune' "${AGENT}" \
  || fail "backup-prune action is not listed as a confirmed mutation"
grep -q 'restore-stage)' "${AGENT}" \
  || fail "restore-stage action missing"
grep -q 'action=restore-stage|mutating=true|confirm=restore-stage|required_arg=backup-path' "${AGENT}" \
  || fail "restore-stage action is not listed as a confirmed mutation with backup path"
grep -q 'validate_backup_path' "${AGENT}" \
  || fail "restore-stage backup path is not validated before sudo"
grep -q 'mqtt-summary)' "${AGENT}" \
  || fail "mqtt-summary action missing"
grep -q 'tls-summary)' "${AGENT}" \
  || fail "tls-summary action missing"
grep -q 'security-summary)' "${AGENT}" \
  || fail "security-summary action missing"
grep -q 'agent-audit-summary)' "${AGENT}" \
  || fail "agent-audit-summary action missing"
grep -q 'action=agent-audit-summary|mutating=false' "${AGENT}" \
  || fail "agent-audit-summary action is not listed as read-only"
grep -q 'start)' "${AGENT}" \
  || fail "start action missing"
grep -q 'action=start|mutating=true|confirm=start' "${AGENT}" \
  || fail "start action is not listed as a confirmed mutation"
grep -q 'action=mqtt-enable-lan|mutating=true|confirm=mqtt-enable-lan|optional_arg=source-cidr' "${AGENT}" \
  || fail "MQTT enable action is not listed with source CIDR"
# shellcheck disable=SC2016
grep -q 'install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent.sh" /usr/bin/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "agent is not installed during provisioning"
grep -q 'useradd .*obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "agent system user is not created during provisioning"
# shellcheck disable=SC2016
grep -q 'install -m 0440 "${REPO_ROOT}/packaging/sudoers/obos-agent" /etc/sudoers.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "agent sudoers policy is not installed during provisioning"
# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/packaging/logrotate/obos-agent" /etc/logrotate.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "agent audit logrotate policy is not installed during provisioning"
grep -q 'obos-agent ALL=(root) NOPASSWD:' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow non-interactive obosctl commands"
grep -q '/usr/bin/obosctl update-rollback-plan' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow update rollback planning"
grep -q '/usr/bin/obosctl backup-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow backup summary"
grep -q '/usr/bin/obosctl backup-prune-plan' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow backup prune planning"
grep -q '/usr/bin/obosctl restore-stage-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow restore stage summary"
grep -q '/usr/bin/obosctl restore-stage-inspect \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore stage inspection"
grep -q '/usr/bin/obosctl restore-apply-plan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore apply planning"
grep -q '/usr/bin/obosctl backup-prune --confirm backup-prune' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow confirmed backup pruning"
grep -q '/usr/bin/obosctl restore-stage \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore staging"
grep -q '/usr/bin/obosctl agent-audit-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow agent audit summary"
grep -q '/usr/bin/obosctl mqtt-enable-lan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow CIDR-limited MQTT enablement"
grep -q '/srv/obos/state/agent/obos-agent-audit.log' packaging/logrotate/obos-agent \
  || fail "agent audit logrotate policy does not target the audit log"
grep -q 'create 0640 obos-agent obos-agent' packaging/logrotate/obos-agent \
  || fail "agent audit logrotate policy does not preserve restrictive ownership"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

cat > "${tmp_dir}/obosctl" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  status-summary)
    echo "format=obos-status-summary-v1"
    exit 0
    ;;
  update-rollback-plan)
    echo "format=obos-update-rollback-plan-v1"
    exit 0
    ;;
  backup-summary)
    echo "format=obos-backup-summary-v1"
    exit 0
    ;;
  backup-prune-plan)
    echo "format=obos-backup-prune-plan-v1"
    exit 0
    ;;
  restore-stage-summary)
    echo "format=obos-restore-stage-summary-v1"
    exit 0
    ;;
  restore-stage-inspect)
    echo "restore-stage-inspected:${2:-missing}"
    exit 0
    ;;
  restore-apply-plan)
    echo "restore-apply-planned:${2:-missing}"
    exit 0
    ;;
  backup-prune)
    [ "${2:-}" = "--confirm" ] && [ "${3:-}" = "backup-prune" ] || exit 2
    echo "format=obos-backup-prune-v1"
    exit 0
    ;;
  restore-stage)
    echo "restore-staged:${2:-missing}"
    exit 0
    ;;
  agent-audit-summary)
    echo "format=obos-agent-audit-summary-v1"
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

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" update-rollback-plan |
  grep -q 'stdout=format=obos-update-rollback-plan-v1' \
  || fail "agent did not expose update rollback plan"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-summary |
  grep -q 'stdout=format=obos-backup-summary-v1' \
  || fail "agent did not expose backup summary"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-prune-plan |
  grep -q 'stdout=format=obos-backup-prune-plan-v1' \
  || fail "agent did not expose backup prune plan"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage-summary |
  grep -q 'stdout=format=obos-restore-stage-summary-v1' \
  || fail "agent did not expose restore stage summary"

OBOS_AGENT_RESTORE_STAGE_DIR="/srv/obos/state/restore-staging" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage-inspect /srv/obos/state/restore-staging/restore.20260605 |
  grep -q 'stdout=restore-stage-inspected:/srv/obos/state/restore-staging/restore.20260605' \
  || fail "agent did not expose restore stage inspection"

if OBOS_AGENT_RESTORE_STAGE_DIR="/srv/obos/state/restore-staging" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage-inspect /tmp/restore.20260605 >/dev/null 2>&1; then
  fail "agent accepted restore stage inspection path outside staging dir"
fi

if OBOS_AGENT_RESTORE_STAGE_DIR="/srv/obos/state/restore-staging" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage-inspect /srv/obos/state/restore-staging/../restore-staging/restore.20260605 >/dev/null 2>&1; then
  fail "agent accepted restore stage inspection path with parent traversal"
fi

OBOS_AGENT_RESTORE_STAGE_DIR="/srv/obos/state/restore-staging" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-apply-plan /srv/obos/state/restore-staging/restore.20260605 |
  grep -q 'stdout=restore-apply-planned:/srv/obos/state/restore-staging/restore.20260605' \
  || fail "agent did not expose restore apply planning"

if OBOS_AGENT_RESTORE_STAGE_DIR="/srv/obos/state/restore-staging" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-apply-plan /tmp/restore.20260605 >/dev/null 2>&1; then
  fail "agent accepted restore apply planning path outside staging dir"
fi

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" agent-audit-summary |
  grep -q 'stdout=format=obos-agent-audit-summary-v1' \
  || fail "agent did not expose agent audit summary"

if OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-prune >/dev/null 2>&1; then
  fail "agent accepted backup prune without confirmation"
fi

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

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-prune --confirm backup-prune |
  grep -q 'stdout=format=obos-backup-prune-v1' \
  || fail "agent did not run confirmed backup prune"

grep -q 'format=obos-agent-audit-v1|.*|action=backup-prune|exit_code=0|timed_out=false' "${tmp_dir}/agent-audit.log" \
  || fail "agent did not audit confirmed backup prune"

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage /srv/obos/backups/obos-openbridgeserver-20260605T080000Z.tar.gz --confirm restore-stage |
  grep -q 'stdout=restore-staged:/srv/obos/backups/obos-openbridgeserver-20260605T080000Z.tar.gz' \
  || fail "agent did not run confirmed restore staging"

grep -q 'format=obos-agent-audit-v1|.*|action=restore-stage|exit_code=0|timed_out=false' "${tmp_dir}/agent-audit.log" \
  || fail "agent did not audit confirmed restore staging"

if OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" restore-stage /tmp/evil.tar.gz --confirm restore-stage >/dev/null 2>&1; then
  fail "agent accepted restore staging backup path outside backup dir"
fi

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mqtt-enable-lan 192.168.1.0/24 --confirm mqtt-enable-lan |
  grep -q 'stdout=mqtt-enabled:192.168.1.0/24' \
  || fail "agent did not forward MQTT source CIDR"

if OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mqtt-enable-lan 999.168.1.0/24 --confirm mqtt-enable-lan >/dev/null 2>&1; then
  fail "agent accepted invalid MQTT source CIDR"
fi

echo "obos-agent: PASS"
