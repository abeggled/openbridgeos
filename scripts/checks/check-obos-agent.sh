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
grep -q 'require_portable_export_args' "${AGENT}" \
  || fail "agent does not validate portable export arguments"
grep -q 'require_portable_import_stage_args' "${AGENT}" \
  || fail "agent does not validate portable import stage arguments"
grep -q 'require_mqtt_enable_args' "${AGENT}" \
  || fail "agent does not validate MQTT enable arguments"
grep -q 'validate_source_cidr' "${AGENT}" \
  || fail "agent does not validate MQTT source CIDR before sudo"
grep -q 'validate_hostname' "${AGENT}" \
  || fail "agent does not validate hostname before sudo"
grep -q 'validate_timezone' "${AGENT}" \
  || fail "agent does not validate timezone before sudo"
# shellcheck disable=SC2016
grep -q 'timeout "${timeout_seconds}"' "${AGENT}" \
  || fail "agent does not enforce command timeout"
grep -q 'status-summary)' "${AGENT}" \
  || fail "status-summary action missing"
grep -q 'action=status-summary|mutating=false' "${AGENT}" \
  || fail "status-summary action is not listed as read-only"
grep -q 'system-summary)' "${AGENT}" \
  || fail "system-summary action missing"
grep -q 'action=system-summary|mutating=false' "${AGENT}" \
  || fail "system-summary action is not listed as read-only"
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
grep -q 'logs-summary)' "${AGENT}" \
  || fail "logs-summary action missing"
grep -q 'action=logs-summary|mutating=false' "${AGENT}" \
  || fail "logs-summary action is not listed as read-only"
grep -q 'logs-tail)' "${AGENT}" \
  || fail "logs-tail action missing"
grep -q 'action=logs-tail|mutating=false' "${AGENT}" \
  || fail "logs-tail action is not listed as read-only"
grep -q 'portable-export-plan)' "${AGENT}" \
  || fail "portable-export-plan action missing"
grep -q 'action=portable-export-plan|mutating=false|required_arg=backup-path' "${AGENT}" \
  || fail "portable-export-plan action is not listed as read-only with backup path"
grep -q 'portable-import-plan)' "${AGENT}" \
  || fail "portable-import-plan action missing"
grep -q 'action=portable-import-plan|mutating=false|required_arg=portable-backup' "${AGENT}" \
  || fail "portable-import-plan action is not listed as read-only with portable backup"
grep -q 'validate_portable_import_path' "${AGENT}" \
  || fail "portable import path is not validated before sudo"
grep -q 'portable-export)' "${AGENT}" \
  || fail "portable-export action missing"
grep -q 'action=portable-export|mutating=true|confirm=portable-export|required_arg=backup-path|required_arg=passphrase-file' "${AGENT}" \
  || fail "portable-export action is not listed as a confirmed mutation with backup path and passphrase file"
grep -q 'action=portable-import-stage|mutating=true|confirm=portable-import-stage|required_arg=portable-backup|required_arg=passphrase-file' "${AGENT}" \
  || fail "portable-import-stage action is not listed as a confirmed mutation with portable backup and passphrase file"
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
grep -q 'mvp-readiness-summary)' "${AGENT}" \
  || fail "mvp-readiness-summary action missing"
grep -q 'action=mvp-readiness-summary|mutating=false' "${AGENT}" \
  || fail "mvp-readiness-summary action is not listed as read-only"
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
grep -q 'action=set-hostname|mutating=true|confirm=set-hostname|required_arg=hostname' "${AGENT}" \
  || fail "set-hostname action is not listed as a confirmed mutation"
grep -q 'action=set-timezone|mutating=true|confirm=set-timezone|required_arg=timezone' "${AGENT}" \
  || fail "set-timezone action is not listed as a confirmed mutation"
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
grep -q '/usr/bin/obosctl system-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow system summary"
grep -q '/usr/bin/obosctl update-rollback-plan' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow update rollback planning"
grep -q '/usr/bin/obosctl backup-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow backup summary"
grep -q '/usr/bin/obosctl backup-prune-plan' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow backup prune planning"
grep -q '/usr/bin/obosctl logs-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow log summary"
grep -q '/usr/bin/obosctl logs-tail' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow bounded log tail"
grep -q '/usr/bin/obosctl portable-export-plan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow portable export planning"
grep -q '/usr/bin/obosctl portable-import-plan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow portable import planning"
grep -q '/usr/bin/obosctl restore-stage-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow restore stage summary"
grep -q '/usr/bin/obosctl restore-stage-inspect \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore stage inspection"
grep -q '/usr/bin/obosctl restore-apply-plan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore apply planning"
grep -q '/usr/bin/obosctl mvp-readiness-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow MVP readiness summary"
grep -q '/usr/bin/obosctl backup-prune --confirm backup-prune' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow confirmed backup pruning"
grep -q '/usr/bin/obosctl portable-export \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow confirmed portable export creation"
grep -q '/usr/bin/obosctl portable-import-stage \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow confirmed portable import staging"
grep -q '/usr/bin/obosctl restore-stage \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked restore staging"
grep -q '/usr/bin/obosctl agent-audit-summary' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow agent audit summary"
grep -q '/usr/bin/obosctl mqtt-enable-lan \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow CIDR-limited MQTT enablement"
grep -q '/usr/bin/obosctl set-hostname \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked hostname changes"
grep -q '/usr/bin/obosctl set-timezone \*' packaging/sudoers/obos-agent \
  || fail "agent sudoers policy does not allow checked timezone changes"
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
  system-summary)
    echo "format=obos-system-summary-v1"
    echo "hostname=obos-test"
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
  logs-summary)
    echo "format=obos-logs-summary-v1"
    echo "raw_logs_exposed=false"
    echo "bounded_logs_exposed=true"
    exit 0
    ;;
  logs-tail)
    echo "format=obos-logs-tail-v1"
    echo "log=journal|test log line"
    exit 0
    ;;
  portable-export-plan)
    echo "portable-export-planned:${2:-missing}"
    echo "format=obos-portable-backup-export-plan-v1"
    exit 0
    ;;
  portable-import-plan)
    echo "portable-import-planned:${2:-missing}"
    echo "format=obos-portable-backup-import-plan-v1"
    exit 0
    ;;
  portable-export)
    echo "portable-exported:${2:-missing}:${3:-missing}"
    echo "format=obos-portable-backup-export-v1"
    echo "portable_backup=/srv/obos/state/portable-backups/obos-portable-test.tar"
    exit 0
    ;;
  portable-import-stage)
    echo "portable-import-staged:${2:-missing}:${3:-missing}"
    echo "format=obos-portable-import-stage-v1"
    echo "decrypted_backup=/srv/obos/state/portable-imports/import.test/backup.tar.gz"
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
  mvp-readiness-summary)
    echo "format=obos-mvp-runtime-readiness-v1"
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
  set-hostname)
    echo "hostname-set:${2:-missing}"
    exit 0
    ;;
  set-timezone)
    echo "timezone-set:${2:-missing}"
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

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" system-summary |
  grep -q 'stdout=hostname=obos-test' \
  || fail "agent did not expose system summary"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" update-rollback-plan |
  grep -q 'stdout=format=obos-update-rollback-plan-v1' \
  || fail "agent did not expose update rollback plan"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-summary |
  grep -q 'stdout=format=obos-backup-summary-v1' \
  || fail "agent did not expose backup summary"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" backup-prune-plan |
  grep -q 'stdout=format=obos-backup-prune-plan-v1' \
  || fail "agent did not expose backup prune plan"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" logs-summary |
  grep -q 'stdout=raw_logs_exposed=false' \
  || fail "agent did not expose metadata-only log summary"

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" logs-tail |
  grep -q 'stdout=log=journal|test log line' \
  || fail "agent did not expose bounded log tail"

OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-export-plan /srv/obos/backups/obos-openbridgeserver-20260605T080000Z.tar.gz |
  grep -q 'stdout=format=obos-portable-backup-export-plan-v1' \
  || fail "agent did not expose portable export plan"

if OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-export-plan /tmp/evil.tar.gz >/dev/null 2>&1; then
  fail "agent accepted portable export backup path outside backup dir"
fi

OBOS_AGENT_PORTABLE_IMPORT_DIR="/srv/obos/state/portable-imports" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-import-plan /srv/obos/state/portable-imports/import.20260605/backup.obos-portable |
  grep -q 'stdout=format=obos-portable-backup-import-plan-v1' \
  || fail "agent did not expose portable import plan"

if OBOS_AGENT_PORTABLE_IMPORT_DIR="/srv/obos/state/portable-imports" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-import-plan /tmp/backup.obos-portable >/dev/null 2>&1; then
  fail "agent accepted portable import path outside import dir"
fi

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

OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mvp-readiness-summary |
  grep -q 'stdout=format=obos-mvp-runtime-readiness-v1' \
  || fail "agent did not expose MVP readiness summary"

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

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-export /srv/obos/backups/obos-openbridgeserver-20260605T080000Z.tar.gz /tmp/obos-agent-passphrase-test --confirm portable-export |
  grep -q 'stdout=format=obos-portable-backup-export-v1' \
  || fail "agent did not run confirmed portable export"

grep -q 'format=obos-agent-audit-v1|.*|action=portable-export|exit_code=0|timed_out=false' "${tmp_dir}/agent-audit.log" \
  || fail "agent did not audit confirmed portable export"

if OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-export /tmp/evil.tar.gz /tmp/obos-agent-passphrase-test --confirm portable-export >/dev/null 2>&1; then
  fail "agent accepted portable export backup path outside backup dir"
fi

if OBOS_AGENT_BACKUP_DIR="/srv/obos/backups" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-export /srv/obos/backups/obos-openbridgeserver-20260605T080000Z.tar.gz /etc/shadow --confirm portable-export >/dev/null 2>&1; then
  fail "agent accepted portable export passphrase file outside /tmp"
fi

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_PORTABLE_IMPORT_DIR="/srv/obos/state/portable-imports" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-import-stage /srv/obos/state/portable-imports/obos-portable-upload-test.tar /tmp/obos-agent-passphrase-test --confirm portable-import-stage |
  grep -q 'stdout=format=obos-portable-import-stage-v1' \
  || fail "agent did not run confirmed portable import staging"

grep -q 'format=obos-agent-audit-v1|.*|action=portable-import-stage|exit_code=0|timed_out=false' "${tmp_dir}/agent-audit.log" \
  || fail "agent did not audit confirmed portable import staging"

if OBOS_AGENT_PORTABLE_IMPORT_DIR="/srv/obos/state/portable-imports" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" portable-import-stage /tmp/obos-portable-upload-test.tar /tmp/obos-agent-passphrase-test --confirm portable-import-stage >/dev/null 2>&1; then
  fail "agent accepted portable import staging path outside import dir"
fi

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mqtt-enable-lan 192.168.1.0/24 --confirm mqtt-enable-lan |
  grep -q 'stdout=mqtt-enabled:192.168.1.0/24' \
  || fail "agent did not forward MQTT source CIDR"

if OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" mqtt-enable-lan 999.168.1.0/24 --confirm mqtt-enable-lan >/dev/null 2>&1; then
  fail "agent accepted invalid MQTT source CIDR"
fi

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" set-hostname obos-test --confirm set-hostname |
  grep -q 'stdout=hostname-set:obos-test' \
  || fail "agent did not forward checked hostname"

if OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" set-hostname '-bad' --confirm set-hostname >/dev/null 2>&1; then
  fail "agent accepted invalid hostname"
fi

OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" set-timezone Europe/Zurich --confirm set-timezone |
  grep -q 'stdout=timezone-set:Europe/Zurich' \
  || fail "agent did not forward checked timezone"

if OBOS_AGENT_AUDIT_LOG="${tmp_dir}/agent-audit.log" OBOS_AGENT_OBOSCTL="${tmp_dir}/obosctl" sh "${AGENT}" set-timezone '../etc/passwd' --confirm set-timezone >/dev/null 2>&1; then
  fail "agent accepted invalid timezone"
fi

echo "obos-agent: PASS"
