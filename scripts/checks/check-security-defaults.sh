#!/usr/bin/env sh
set -eu

fail() {
  echo "security check failed: $1" >&2
  exit 1
}

! grep -R --exclude=check-security-defaults.sh "changeme\|password123\|secret123" \
  apps scripts packaging docs README.md SECURITY.md >/dev/null 2>&1 \
  || fail "default placeholder secret found"

grep -q 'APPLIANCE_ID_FILE=' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier path is not defined on first boot"

grep -q 'ONBOARDING_REQUIRED_FILE=' scripts/bootstrap/first-boot.sh \
  || fail "first boot does not define the web onboarding marker"

grep -q 'format=obos-onboarding-required-v1' scripts/bootstrap/first-boot.sh \
  || fail "first boot does not create a machine-readable web onboarding marker"

grep -q 'window_seconds=300' scripts/bootstrap/first-boot.sh \
  || fail "first boot onboarding window is not limited to 300 seconds"

grep -q 'refresh_onboarding_window' scripts/bootstrap/first-boot.sh \
  || fail "first boot does not reopen onboarding after reboot when no password exists"

grep -q 'generate-web-auth.sh' scripts/bootstrap/provision-debian.sh \
  || fail "web console auth helper is not installed during provisioning"

grep -q 'WEB_AUTH_FILE=' scripts/auth/generate-web-auth.sh \
  || fail "web console auth helper does not define a password file"

grep -q 'WEB_AUTH_INFO_FILE=' scripts/auth/generate-web-auth.sh \
  || fail "web console auth helper does not define credential record file"

grep -q 'openssl passwd -apr1 -stdin' scripts/auth/generate-web-auth.sh \
  || fail "web console auth helper does not hash passwords for nginx basic auth"

# shellcheck disable=SC2016
grep -q 'MODE="${1:-generate}"' scripts/auth/generate-web-auth.sh \
  || fail "web console auth helper does not default to generate mode"

grep -q 'generate|rotate|set' scripts/auth/generate-web-auth.sh \
  || fail "web console auth helper does not support setup and rotation"

# shellcheck disable=SC2016
grep -q 'password=${password}' scripts/auth/generate-web-auth.sh \
  || fail "web console auth rotation does not print the new password intentionally"

grep -q 'install -m 0640' scripts/auth/generate-web-auth.sh \
  || fail "web console auth password file is not installed with restrictive permissions"

grep -q 'install -m 0600' scripts/auth/generate-web-auth.sh \
  || fail "web console credential record is not installed with restrictive permissions"

if grep -q 'auth_basic "open bridge operating system";' packaging/nginx/openbridgeserver.conf; then
  fail "nginx must not use browser Basic Auth for obos web/API"
fi

grep -q 'SESSION_COOKIE = "obos_session"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not define the GUI session cookie"

grep -q 'handle_session_login' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not expose GUI login handling"

grep -q 'require_session' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not protect API calls with a session"

grep -q 'SupplementaryGroups=www-data' packaging/systemd/obos-agent-http.service \
  || fail "HTTP bridge cannot read nginx htpasswd group file"

grep -q 'web-auth-rotate)' scripts/obosctl \
  || fail "obosctl does not expose web auth rotation"

grep -q 'web-auth-set)' scripts/obosctl \
  || fail "obosctl does not expose initial web auth setup"

grep -q 'WEB_AUTH_SCRIPT=' scripts/obosctl \
  || fail "obosctl does not define web auth helper"

grep -q 'action=web-auth-set|mutating=true|confirm=web-auth-set' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not expose confirmed initial web auth setup"

grep -q 'action=web-auth-rotate|mutating=true|confirm=web-auth-rotate' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not expose confirmed web auth rotation"

grep -q '"web-auth-set": "web-auth-set"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not expose confirmed initial web auth setup"

grep -q '"web-auth-rotate": "web-auth-rotate"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not expose confirmed web auth rotation"

grep -q '/usr/bin/obosctl web-auth-set \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow initial web auth setup"

grep -q '/usr/bin/obosctl web-auth-rotate' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow web auth rotation"

grep -q 'OBOS-ONBOARDING.txt' scripts/tls/export-boot-trust-summary.sh \
  || fail "boot onboarding summary does not define an onboarding file"

grep -q 'set during first web onboarding' scripts/tls/export-boot-trust-summary.sh \
  || fail "boot onboarding summary does not point to first web onboarding"

grep -q 'This file does not contain a password' scripts/tls/export-boot-trust-summary.sh \
  || fail "boot onboarding summary does not state that passwords are not exported"

if grep -q 'initial web console password' scripts/tls/export-boot-trust-summary.sh; then
  fail "boot onboarding summary must not export an initial web console password"
fi

# shellcheck disable=SC2016
grep -Fq 'uuid > "${APPLIANCE_ID_FILE}"' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier is not generated on first boot"

grep -q 'format=obos-first-boot-v1' scripts/bootstrap/first-boot.sh \
  || fail "first boot marker does not declare a machine-readable format"

# shellcheck disable=SC2016
grep -q 'install -m 0640 "${marker_tmp}" "${FIRST_BOOT_MARKER}"' scripts/bootstrap/first-boot.sh \
  || fail "first boot marker is not installed with restrictive permissions"

grep -q 'check_first_boot_marker' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit first boot marker"

grep -q 'format=obos-first-boot-v1' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify first boot marker format"

grep -q 'rm -f /srv/obos/state/first-boot.done' scripts/images/build-amd64-qcow2.sh \
  || fail "qcow2 builder does not leave first boot pending with the correct marker path"

# shellcheck disable=SC2016
grep -q 'rm -f "${BUILD_ROOT}/srv/obos/state/first-boot.done"' scripts/images/build-rpi4-arm64-image.sh \
  || fail "Raspberry Pi builder does not leave first boot pending with the correct marker path"

! grep -q '/etc/obos/first-boot.done' scripts/images/build-amd64-qcow2.sh scripts/images/build-rpi4-arm64-image.sh \
  || fail "image builders still reference the old first boot marker path"

grep -q 'APPLIANCE_ID_FILE=' scripts/obosctl \
  || fail "obosctl backup does not know the appliance identifier path"

grep -q 'appliance_id_name' scripts/obosctl \
  || fail "obosctl backup does not include appliance identifier"

grep -q 'obos-backup-manifest.txt' scripts/obosctl \
  || fail "obosctl backup does not include a backup manifest"

grep -q 'contains_secrets=true' scripts/obosctl \
  || fail "obosctl backup manifest does not mark secret-bearing backups"

grep -q 'backup-list)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable backup inventory"

grep -q 'backup-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable backup summary"

grep -q 'system-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable system summary"

grep -q 'format=obos-system-summary-v1' scripts/obosctl \
  || fail "obosctl system summary does not declare a format"

grep -q 'backup-prune-plan)' scripts/obosctl \
  || fail "obosctl does not expose non-destructive backup pruning plan"

grep -q 'backup-prune)' scripts/obosctl \
  || fail "obosctl does not expose confirmed backup pruning"

grep -q 'format=obos-backup-list-v1' scripts/obosctl \
  || fail "obosctl backup list does not declare a format"

grep -q 'format=obos-backup-summary-v1' scripts/obosctl \
  || fail "obosctl backup summary does not declare a format"

grep -q 'format=obos-backup-prune-plan-v1' scripts/obosctl \
  || fail "obosctl backup prune plan does not declare a format"

grep -q 'format=obos-backup-prune-v1' scripts/obosctl \
  || fail "obosctl backup prune does not declare a format"

grep -q 'agent-audit-summary)' scripts/obosctl \
  || fail "obosctl does not expose agent audit summary"

grep -q 'format=obos-agent-audit-summary-v1' scripts/obosctl \
  || fail "obosctl agent audit summary does not declare a format"

grep -q 'mode=non-destructive' scripts/obosctl \
  || fail "obosctl backup prune plan does not declare non-destructive mode"

grep -q 'mode=dry-run' scripts/obosctl \
  || fail "obosctl backup prune does not default to dry run"

grep -q -- '--confirm backup-prune' scripts/obosctl \
  || fail "obosctl backup prune does not require explicit confirmation"

grep -q 'backup_count=' scripts/obosctl \
  || fail "obosctl backup list does not report backup count"

grep -q 'latest_backup_present=' scripts/obosctl \
  || fail "obosctl backup summary does not report latest backup presence"

grep -q 'latest_backup_inspection=' scripts/obosctl \
  || fail "obosctl backup summary does not report latest backup inspection status"

grep -q 'latest_backup_contains_secrets=' scripts/obosctl \
  || fail "obosctl backup summary does not report secret-bearing status"

grep -q 'latest_backup_includes_logs=' scripts/obosctl \
  || fail "obosctl backup summary does not report log inclusion status"

grep -q 'logs-summary)' scripts/obosctl \
  || fail "obosctl does not expose metadata-only log summary"

grep -q 'format=obos-logs-summary-v1' scripts/obosctl \
  || fail "obosctl log summary does not declare a format"

grep -q 'raw_logs_exposed=false' scripts/obosctl \
  || fail "obosctl log summary must not expose raw log contents"

grep -q 'portable-export-plan)' scripts/obosctl \
  || fail "obosctl does not expose non-destructive portable export planning"

grep -q 'portable-export)' scripts/obosctl \
  || fail "obosctl does not expose encrypted portable export creation"

grep -q 'format=obos-portable-backup-export-plan-v1' scripts/obosctl \
  || fail "portable export plan does not declare a format"

grep -q 'format=obos-portable-backup-export-v1' scripts/obosctl \
  || fail "portable export does not declare a format"

grep -q 'raw_backup_download_allowed=false' scripts/obosctl \
  || fail "portable export plan does not block raw backup downloads"

grep -q 'authenticated_encryption_required=true' scripts/obosctl \
  || fail "portable export plan does not require authenticated encryption"

grep -q 'gpg --batch --yes --pinentry-mode loopback' scripts/obosctl \
  || fail "portable export does not use non-interactive GnuPG encryption"

grep -q -- '--force-mdc' scripts/obosctl \
  || fail "portable export does not force GnuPG modification detection"

grep -q 'payload_sha256=' scripts/obosctl \
  || fail "portable export does not record payload hash"

grep -q 'backup_manifest_sha256=' scripts/obosctl \
  || fail "portable export does not record backup manifest hash"

grep -q 'chgrp obos-agent' scripts/obosctl \
  || fail "portable export artifact is not made readable by the agent group"

grep -q 'chmod 0640' scripts/obosctl \
  || fail "portable export artifact is not kept group-readable and private"

grep -q 'DOWNLOAD_PREFIX = "/obos/api/v1/downloads/portable-export"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not expose a dedicated portable export download endpoint"

grep -q 'UPLOAD_PREFIX = "/obos/api/v1/uploads/portable-import"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not expose a dedicated portable import upload endpoint"

grep -q 'application/octet-stream' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not require octet-stream for portable imports"

grep -q 'MAX_UPLOAD_BYTES' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not bound portable import uploads"

grep -q 'ReadWritePaths=/srv/obos/state/portable-imports' packaging/systemd/obos-agent-http.service \
  || fail "HTTP bridge service does not restrict write access to portable imports"

grep -q 'install -d -m 0700 -o obos-agent -g obos-agent /srv/obos/state/portable-imports' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not create private portable import upload directory"

grep -q 'only encrypted portable export artifacts are downloadable' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not reject non-portable download artifacts"

grep -q 'download-forbidden' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not reject forbidden portable download paths"

grep -q 'gnupg' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install GnuPG for portable exports"

grep -q 'portable-import-plan)' scripts/obosctl \
  || fail "obosctl does not expose non-destructive portable import planning"

grep -q 'portable-import-stage)' scripts/obosctl \
  || fail "obosctl does not expose private portable import staging"

grep -q 'portable-import-stage)' scripts/agent/obos-agent.sh \
  || fail "agent does not expose confirmed private portable import staging"

grep -q 'format=obos-portable-backup-import-plan-v1' scripts/obosctl \
  || fail "portable import plan does not declare a format"

grep -q 'format=obos-portable-import-stage-v1' scripts/obosctl \
  || fail "portable import staging does not declare a format"

grep -q 'live_apply_allowed=false' scripts/obosctl \
  || fail "portable import plan must not allow live apply"

grep -q 'mode=private-import-staging' scripts/obosctl \
  || fail "portable import staging does not use private staging mode"

grep -q 'restore_inspection=pass' scripts/obosctl \
  || fail "portable import staging does not require restore inspection"

grep -q 'latest_backup_tls_private_keys=' scripts/obosctl \
  || fail "obosctl backup summary does not report TLS private key status"

grep -q 'includes_logs=false' scripts/obosctl \
  || fail "obosctl backup manifest does not record log exclusion"

grep -q -- '--exclude=mqtt/log' scripts/obosctl \
  || fail "obosctl backup does not exclude Mosquitto logs by default"

[ -f docs/decisions/0005-encrypted-portable-backups.md ] \
  || fail "encrypted portable backup decision is missing"

grep -q 'obos-portable-backup-v1' docs/decisions/0005-encrypted-portable-backups.md \
  || fail "encrypted portable backup decision does not define a format"

grep -q 'must not download raw appliance backup archives' docs/decisions/0005-encrypted-portable-backups.md \
  || fail "encrypted portable backup decision allows raw web downloads"

grep -q 'authenticated encryption envelope' docs/decisions/0005-encrypted-portable-backups.md \
  || fail "encrypted portable backup decision does not require authenticated encryption"

grep -q 'private import staging' docs/decisions/0005-encrypted-portable-backups.md \
  || fail "encrypted portable backup decision does not require private import staging"

grep -q 'obos-portable-backup-v1' docs/security.md \
  || fail "security model does not reference encrypted portable backups"

grep -q 'restore-inspect)' scripts/obosctl \
  || fail "obosctl does not expose restore inspection"

grep -q 'restore-plan)' scripts/obosctl \
  || fail "obosctl does not expose restore planning"

grep -q 'restore-stage)' scripts/obosctl \
  || fail "obosctl does not expose restore staging"

grep -q 'restore-stage-inspect)' scripts/obosctl \
  || fail "obosctl does not expose restore stage inspection"

grep -q 'restore-stage-summary)' scripts/obosctl \
  || fail "obosctl does not expose restore stage summary"

grep -q 'restore-apply-plan)' scripts/obosctl \
  || fail "obosctl does not expose restore apply planning"

grep -q 'restore-apply)' scripts/obosctl \
  || fail "obosctl does not expose confirmed restore apply"

grep -q -- '--confirm restore-apply' scripts/obosctl \
  || fail "restore apply does not require explicit confirmation"

grep -q 'pre_restore_backup=' scripts/obosctl \
  || fail "restore apply does not record a pre-restore backup"

grep -q 'format=obos-restore-apply-v1' scripts/obosctl \
  || fail "restore apply does not declare a machine-readable format"

grep -q 'require_restore_apply_targets_safe' scripts/obosctl \
  || fail "restore apply does not validate live target paths"

grep -q 'stage directory must be below' scripts/obosctl \
  || fail "restore apply does not validate stage directory scope"

if grep -q '"restore-apply": "restore-apply"' scripts/agent/obos-agent-http.py; then
  fail "HTTP bridge must not expose restore apply"
fi

if grep -q 'data-mutation-action="restore-apply"' apps/obos-web/index.html; then
  fail "web UI must not expose restore apply"
fi

grep -q 'RESTORE_STAGE_DIR=' scripts/obosctl \
  || fail "restore staging does not use a dedicated staging directory"

grep -q 'mode=staged-only' scripts/obosctl \
  || fail "restore staging does not declare staged-only mode"

grep -q 'format=obos-restore-stage-v1' scripts/obosctl \
  || fail "restore staging does not write a stage manifest"

grep -q 'format=obos-restore-stage-summary-v1' scripts/obosctl \
  || fail "restore stage summary does not declare a format"

grep -q 'restore stage inspect: PASS' scripts/obosctl \
  || fail "restore stage inspection does not report success"

grep -q 'Mosquitto logs absent' scripts/obosctl \
  || fail "restore stage inspection does not verify log exclusion"

grep -q 'next=review staged files, then run: sudo obosctl restore-apply-plan' scripts/obosctl \
  || fail "restore stage output does not point to restore apply planning"

! grep -q 'future restore apply command' scripts/obosctl \
  || fail "restore stage output still references a future restore apply command"

grep -q 'format=obos-restore-apply-plan-v1' scripts/obosctl \
  || fail "restore apply plan does not declare a format"

grep -q 'restore apply plan: blocked; restore stage inspection failed' scripts/obosctl \
  || fail "restore apply plan does not require stage inspection"

grep -q 'sudo obosctl restore-apply' scripts/obosctl \
  || fail "restore apply plan does not point to the confirmed apply command"

# shellcheck disable=SC2016
grep -q 'chmod 0600 "${stage_manifest}"' scripts/obosctl \
  || fail "restore stage manifest permissions are not restrictive"

grep -q 'restore inspect: PASS' scripts/obosctl \
  || fail "restore inspection does not report success"

grep -q 'format=obos-restore-plan-v1' scripts/obosctl \
  || fail "restore plan does not declare a format"

grep -q 'mode=non-destructive' scripts/obosctl \
  || fail "restore plan does not declare non-destructive mode"

grep -q 'restore preserves appliance TLS identity' scripts/obosctl \
  || fail "restore plan does not explain TLS identity impact"

grep -q 'unsafe absolute or parent-relative paths' scripts/obosctl \
  || fail "restore inspection does not reject unsafe archive paths"

grep -q 'TLS private key material present' scripts/obosctl \
  || fail "restore inspection does not report TLS identity material"

grep -q 'LAST_UPDATE_FILE=' scripts/obosctl \
  || fail "obosctl update does not track last update state"

grep -q 'format=obos-update-v1' scripts/obosctl \
  || fail "obosctl update state does not declare a format"

grep -q 'update-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable update status"

grep -q 'update-rollback-plan)' scripts/obosctl \
  || fail "obosctl does not expose a last-update rollback plan"

grep -q 'update-rollback-stage)' scripts/obosctl \
  || fail "obosctl does not expose last-update rollback staging"

grep -q 'format=obos-update-summary-v1' scripts/obosctl \
  || fail "obosctl update summary does not declare a format"

grep -q 'format=obos-update-rollback-plan-v1' scripts/obosctl \
  || fail "obosctl update rollback plan does not declare a format"

grep -q 'format=obos-update-rollback-stage-v1' scripts/obosctl \
  || fail "obosctl update rollback stage does not declare a format"

grep -q 'last_update_present=' scripts/obosctl \
  || fail "obosctl update summary does not report update presence"

grep -q 'health_https_proxy=ok' scripts/obosctl \
  || fail "obosctl update state does not record HTTPS proxy health"

grep -q 'pre_update_backup_required=true' scripts/obosctl \
  || fail "obosctl update state does not record pre-update backup requirement"

grep -q 'pre_update_backup_created=true' scripts/obosctl \
  || fail "obosctl update state does not record pre-update backup creation"

grep -q 'update: blocked; pre-update backup was not created' scripts/obosctl \
  || fail "obosctl update does not block when the pre-update backup is missing"

grep -q 'update rollback plan: blocked; backup inspection failed' scripts/obosctl \
  || fail "obosctl update rollback plan does not require backup inspection"

grep -q 'update rollback stage: blocked; backup inspection failed' scripts/obosctl \
  || fail "obosctl update rollback stage does not require backup inspection"

grep -q 'live_apply_allowed=false' scripts/obosctl \
  || fail "obosctl update rollback stage does not keep live apply disabled"

grep -q 'restore-apply-plan <stage-dir>' scripts/obosctl \
  || fail "obosctl update rollback plan does not end with restore apply planning"

! grep -q 'future apply command' scripts/obosctl \
  || fail "obosctl update rollback plan still references a future apply command"

grep -q 'last-update:' scripts/obosctl \
  || fail "obosctl status does not show last update state"

grep -q 'status-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable status"

grep -q 'format=obos-status-summary-v1' scripts/obosctl \
  || fail "obosctl status summary does not declare a format"

# shellcheck disable=SC2016
grep -Fq 'health_https_proxy=${health_https_proxy}' scripts/obosctl \
  || fail "obosctl status summary does not report HTTPS proxy health"

grep -q 'check-web-ui-agent-contract.sh' .github/workflows/ci.yml \
  || fail "CI does not validate the web UI agent contract"

grep -q 'check-obos-agent.sh' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent"

grep -q 'check-obos-web.sh' .github/workflows/ci.yml \
  || fail "CI does not validate obos-web"

grep -q 'data-agent-field="security-summary:' apps/obos-web/index.html \
  || fail "obos-web does not surface security baseline data"

grep -q 'data-agent-field="agent-audit-summary:' apps/obos-web/index.html \
  || fail "obos-web does not surface agent audit data"

grep -q 'OBOS_WEB_DIR="/srv/obos/web"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not define obos-web install directory"

grep -q 'apps/obos-web/index.html' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web index"

grep -q 'apps/obos-web/styles.css' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web styles"

grep -q 'sudo visudo -cf packaging/sudoers/obos-agent' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent sudoers syntax"

grep -q 'sudo logrotate --debug packaging/logrotate/obos-agent' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent logrotate syntax"

grep -q 'sudo' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install sudo for the agent privilege boundary"

grep -q 'logrotate' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install logrotate for agent audit logs"

grep -q 'useradd .*obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not create the obos-agent system user"

# shellcheck disable=SC2016
grep -q 'install -m 0440 "${REPO_ROOT}/packaging/sudoers/obos-agent" /etc/sudoers.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install the obos-agent sudoers policy"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/packaging/logrotate/obos-agent" /etc/logrotate.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install the obos-agent logrotate policy"

grep -q 'obos-agent ALL=(root) NOPASSWD:' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not use an allowlisted root boundary"

grep -q 'create 0640 obos-agent obos-agent' packaging/logrotate/obos-agent \
  || fail "obos-agent logrotate policy does not preserve restrictive ownership"

grep -q 'format=obos-agent-response-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare a response format"

grep -q 'format=obos-agent-actions-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare an action inventory format"

grep -q 'format=obos-agent-audit-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare a mutation audit format"

grep -q 'OBOS_AGENT_AUDIT_LOG' scripts/agent/obos-agent.sh \
  || fail "obos-agent audit log path is not configurable"

grep -q 'write_audit_log' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not audit mutating actions"

# shellcheck disable=SC2016
grep -q 'sudo -n "${OBOSCTL}"' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not use non-interactive sudo for obosctl"

grep -q 'action=status-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark read-only actions"

grep -q 'action=system-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark system summary as read-only"

grep -q 'action=update-rollback-plan|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark update rollback planning as read-only"

grep -q 'action=backup-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark backup summary as read-only"

grep -q 'action=backup-prune-plan|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark backup pruning plan as read-only"

grep -q 'action=logs-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark log summary as read-only"

grep -q 'action=portable-export-plan|mutating=false|required_arg=backup-path' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark portable export planning as read-only"

grep -q 'action=portable-import-plan|mutating=false|required_arg=portable-backup' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark portable import planning as read-only"

grep -q 'validate_portable_import_path' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not validate portable import paths before sudo"

grep -q 'action=restore-stage-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark restore stage summary as read-only"

grep -q 'action=restore-stage-inspect|mutating=false|required_arg=stage-dir' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark restore stage inspection as read-only"

grep -q 'action=restore-apply-plan|mutating=false|required_arg=stage-dir' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark restore apply planning as read-only"

grep -q 'validate_restore_stage_path' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not validate restore stage path before sudo"

grep -q 'action=backup-prune|mutating=true|confirm=backup-prune' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark backup pruning as a confirmed mutation"

grep -q 'action=restore-stage|mutating=true|confirm=restore-stage|required_arg=backup-path' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark restore staging as a confirmed mutation"

grep -q 'validate_backup_path' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not validate restore backup path before sudo"

grep -q 'action=agent-audit-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark audit summary as read-only"

grep -q 'action=start|mutating=true|confirm=start' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark confirmed mutations"

grep -q 'MUTATING_ACTIONS' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not keep a mutation allowlist"

grep -q '"backup": "backup"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict backup mutation confirmation"

grep -q '"start": "start"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict start mutation confirmation"

grep -q '"stop": "stop"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict stop mutation confirmation"

grep -q '"restart": "restart"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict restart mutation confirmation"

grep -q '"restore-stage": "restore-stage"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict restore-stage mutation confirmation"

grep -q '"update": "update"' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not restrict update mutation confirmation"

grep -q 'application/json' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge mutations do not require JSON"

grep -q 'MAX_POST_BYTES = 1024' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge mutation body size is not bounded"

grep -q 'expected_fields = {"confirm"}' scripts/agent/obos-agent-http.py \
  || fail "HTTP bridge does not reject unexpected mutation body fields"

grep -q 'data-mutation-action="backup"' apps/obos-web/index.html \
  || fail "web UI does not expose confirmed backup mutation"

grep -q 'data-mutation-action="restore-stage"' apps/obos-web/index.html \
  || fail "web UI does not expose confirmed restore-stage mutation"

grep -q 'data-mutation-backup-from="backup-summary:latest_backup"' apps/obos-web/index.html \
  || fail "web UI restore-stage mutation does not source latest backup"

grep -q 'data-mutation-action="restart"' apps/obos-web/index.html \
  || fail "web UI does not expose confirmed service lifecycle mutations"

grep -q 'data-mutation-action="update"' apps/obos-web/index.html \
  || fail "web UI does not expose confirmed update mutation"

grep -q '/usr/bin/obosctl update-rollback-plan' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow update rollback planning"

grep -q '/usr/bin/obosctl system-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow system summary"

grep -q '/usr/bin/obosctl backup-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow backup summary"

grep -q '/usr/bin/obosctl backup-prune-plan' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow backup prune planning"

grep -q '/usr/bin/obosctl logs-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow log summary"

grep -q '/usr/bin/obosctl portable-export-plan \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow portable export planning"

grep -q '/usr/bin/obosctl portable-import-plan \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow portable import planning"

grep -q '/usr/bin/obosctl restore-stage-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow restore stage summary"

grep -q '/usr/bin/obosctl restore-stage-inspect \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow checked restore stage inspection"

grep -q '/usr/bin/obosctl restore-apply-plan \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow checked restore apply planning"

grep -q '/usr/bin/obosctl backup-prune --confirm backup-prune' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow confirmed backup pruning"

grep -q '/usr/bin/obosctl restore-stage \*' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow checked restore staging"

grep -q '/usr/bin/obosctl agent-audit-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow agent audit summary"

grep -q 'require_no_extra_args' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not reject extra arguments"

grep -q 'require_confirm_args' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not require confirmation for mutations"

grep -q 'validate_source_cidr' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not validate MQTT source CIDR before sudo"

# shellcheck disable=SC2016
grep -q 'timeout "${timeout_seconds}"' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not enforce command timeouts"

grep -q 'proxy-health)' scripts/obosctl \
  || fail "obosctl does not expose verified HTTPS proxy health"

grep -q 'PROXY_HEALTH_HOST=' scripts/obosctl \
  || fail "obosctl proxy health does not use an explicit TLS hostname"

grep -q -- '--cacert' scripts/obosctl \
  || fail "obosctl proxy health does not verify the local CA"

grep -q -- '--resolve' scripts/obosctl \
  || fail "obosctl proxy health does not resolve the TLS hostname locally"

grep -q 'APPLIANCE_ID_FILE=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit appliance identifier"

grep -q 'WEB_AUTH_FILE=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit web console auth file"

# shellcheck disable=SC2016
grep -q 'check_file_mode "${WEB_AUTH_FILE}" 640' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit web console auth file permissions"

# shellcheck disable=SC2016
grep -q 'check_file_mode "${WEB_AUTH_INFO_FILE}" 600' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit web console credential record permissions"

grep -q 'WEB_AUTH_URL=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not define web console auth probe URL"

grep -q 'check_web_auth' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify web console auth challenge"

# shellcheck disable=SC2016
grep -q -- '--user "${web_user}:${web_password}"' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify generated web console credentials"

grep -q 'AGENT_AUDIT_LOG=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit agent audit log"

grep -q 'check_command obos-agent' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit obos-agent installation"

grep -q 'check_command python3' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit Python runtime for agent HTTP bridge"

grep -q 'check_user obos-agent' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit obos-agent user"

grep -q 'AGENT_SUDOERS=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit obos-agent sudoers policy"

grep -q 'AGENT_LOGROTATE=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit obos-agent logrotate policy"

# shellcheck disable=SC2016
grep -q 'check_optional_file_mode "${AGENT_AUDIT_LOG}" 640' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit agent audit log permissions"

grep -q 'security-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable security baseline status"

grep -q 'format=obos-security-baseline-summary-v1' scripts/audit/security-baseline.sh \
  || fail "security baseline does not expose a summary format"

grep -q 'fail_count=' scripts/audit/security-baseline.sh \
  || fail "security baseline summary does not report failure count"

grep -q 'PROXY_HEALTH_HOST=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify HTTPS proxy hostname"

grep -q -- '--cacert' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify HTTPS proxy local CA trust"

grep -q 'NGINX_PROXY_CONF=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx reverse proxy config"

grep -q 'server_tokens off;' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx server token disclosure"

grep -q 'client_header_timeout 30s;' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx client header timeout"

grep -q 'check_obos_systemd_hardening obos-first-boot.service' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit first boot systemd hardening"

grep -q 'check_obos_systemd_hardening obos-openbridgeserver.service' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit open bridge server systemd hardening"

grep -q 'check_openbridgeserver_systemd_runtime' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit open bridge server runtime policy"

grep -q 'Restart on-failure' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit open bridge server failed-start retry"

grep -q 'RestartUSec 30s' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit open bridge server retry delay"

grep -q 'check_agent_http_systemd_hardening' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit obos-agent-http systemd hardening"

grep -q 'check_systemd_active obos-agent-http.service' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit active obos-agent-http service"

grep -q 'NoNewPrivileges no' scripts/audit/security-baseline.sh \
  || fail "security baseline does not preserve sudo-compatible agent HTTP hardening"

grep -q 'NoNewPrivileges yes' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit systemd NoNewPrivileges"

grep -q 'SystemCallArchitectures native' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit systemd syscall architecture"

grep -q 'OBS_HTTP_HOST_PORT=127.0.0.1:8080' scripts/bootstrap/first-boot.sh \
  || fail "open bridge server HTTP is not localhost-only by default"

grep -q 'OBS_MQTT_HOST_PORT=127.0.0.1:1883' scripts/bootstrap/first-boot.sh \
  || fail "MQTT plain listener is not localhost by default"

grep -q 'OBS_MQTT_WS_HOST_PORT=127.0.0.1:9001' scripts/bootstrap/first-boot.sh \
  || fail "MQTT websocket listener is not localhost by default"

# shellcheck disable=SC2016
grep -Fq 'OBS_JWT_SECRET=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "OBS JWT secret is not generated on first boot"

# shellcheck disable=SC2016
grep -Fq 'OBS_MQTT_PASSWORD=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "MQTT password is not generated on first boot"

grep -q 'TLS_GENERATE_SCRIPT=' scripts/bootstrap/first-boot.sh \
  || fail "TLS material is not generated on first boot"

grep -q 'BOOT_TRUST_SCRIPT=' scripts/bootstrap/first-boot.sh \
  || fail "boot-accessible TLS trust summary is not exported on first boot"

grep -q 'nginx-light' scripts/bootstrap/provision-debian.sh \
  || fail "nginx reverse proxy package is not installed during provisioning"

grep -q 'docker-cli' scripts/bootstrap/provision-debian.sh \
  || fail "Docker CLI package is not installed during provisioning"

grep -q 'docker.io' scripts/bootstrap/provision-debian.sh \
  || fail "Docker daemon package is not installed during provisioning"

grep -q 'unattended-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "unattended security upgrade package is not installed during provisioning"

grep -q '20auto-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "apt periodic unattended upgrade config is not installed"

grep -q '50unattended-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "unattended upgrade policy config is not installed"

grep -q 'apt-daily-upgrade.timer' scripts/bootstrap/provision-debian.sh \
  || fail "apt unattended upgrade timer is not enabled"

grep -q '20-obos-dhcp.network' scripts/bootstrap/provision-debian.sh \
  || fail "DHCP network profile is not installed during provisioning"

grep -q 'systemctl enable systemd-networkd.service' scripts/bootstrap/provision-debian.sh \
  || fail "systemd-networkd is not enabled during provisioning"

grep -q 'DHCP=yes' packaging/network/20-obos-dhcp.network \
  || fail "VM network profile does not enable DHCP"

grep -q 'Name=en\* eth\*' packaging/network/20-obos-dhcp.network \
  || fail "VM network profile does not match common Ethernet interfaces"

grep -q 'Unattended-Upgrade "1"' packaging/apt/20auto-upgrades \
  || fail "apt periodic unattended upgrades are not enabled"

grep -q 'Debian-Security' packaging/apt/50unattended-upgrades \
  || fail "unattended upgrades are not restricted to Debian security origins"

grep -q 'Automatic-Reboot "false"' packaging/apt/50unattended-upgrades \
  || fail "unattended upgrades allow automatic reboot"

grep -q 'OBOS_IMAGE_DEFAULT_SSH=disabled' packaging/images/profiles/rpi4-arm64.env \
  || fail "Raspberry Pi image profile does not disable SSH by default"

grep -q 'expect_value ssh_default disabled' scripts/images/check-rpi-image-manifest.sh \
  || fail "Raspberry Pi image manifest does not record disabled SSH by default"

grep -q 'systemctl enable nginx.service' scripts/bootstrap/provision-debian.sh \
  || fail "nginx service is not enabled during provisioning"

grep -q 'set-mqtt-lan-access.sh' scripts/bootstrap/provision-debian.sh \
  || fail "MQTT LAN opt-in helper is not installed during provisioning"

grep -q 'OBOS_MQTT_LAN_SOURCE_CIDR' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support source CIDR restriction"

grep -q 'is_ipv4_cidr' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not validate IPv4 CIDR numerically"

grep -q 'export-boot-trust-summary.sh' scripts/bootstrap/provision-debian.sh \
  || fail "boot trust summary helper is not installed during provisioning"

grep -q 'check-tls-status.sh' scripts/bootstrap/provision-debian.sh \
  || fail "TLS status helper is not installed during provisioning"

grep -q '"no-new-privileges": true' packaging/docker/daemon.json \
  || fail "Docker no-new-privileges default is not enabled"

grep -q '"log-driver": "local"' packaging/docker/daemon.json \
  || fail "Docker local log driver is not configured"

grep -q 'policy drop' packaging/nftables/obos.nft \
  || fail "nftables input policy is not default-drop"

grep -q 'tcp dport 443 accept' packaging/nftables/obos.nft \
  || fail "HTTPS reverse proxy port is not allowed"

! grep -q 'tcp dport 8080 accept' packaging/nftables/obos.nft \
  || fail "Direct open bridge server HTTP is open in the default firewall"

grep -q 'HOST_HTTP_PORT=' scripts/images/smoke-test-amd64-qcow2.sh \
  || fail "qcow2 smoke test does not probe direct open bridge server HTTP"

grep -q 'direct open bridge server HTTP is reachable' scripts/images/smoke-test-amd64-qcow2.sh \
  || fail "qcow2 smoke test does not fail when direct HTTP is reachable"

grep -q 'qemu exited before HTTPS health passed' scripts/images/smoke-test-amd64-qcow2.sh \
  || fail "qcow2 smoke test does not fail when qemu exits early"

! grep -q 'tcp dport 1883 accept' packaging/nftables/obos.nft \
  || fail "MQTT plain TCP is open in the default firewall"

! grep -q 'tcp dport 9001 accept' packaging/nftables/obos.nft \
  || fail "MQTT WebSocket is open in the default firewall"

grep -q 'OBOS MQTT LAN BEGIN' packaging/nftables/obos.nft \
  || fail "nftables MQTT LAN managed block is missing"

grep -q 'tcp dport 1883 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT plain TCP when enabled"

grep -q 'tcp dport 9001 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT WebSocket when enabled"

grep -q 'ip saddr %s' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support IPv4 source-restricted firewall rules"

grep -q 'ip6 saddr %s' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support IPv6 source-restricted firewall rules"

grep -q 'OBS_MQTT_HOST_PORT 0.0.0.0:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not publish MQTT plain TCP when enabled"

grep -q 'OBS_MQTT_HOST_PORT 127.0.0.1:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not restore localhost MQTT plain TCP"

grep -q 'udp sport 67 udp dport 68 accept' packaging/nftables/obos.nft \
  || fail "DHCPv4 client renewals are not allowed"

grep -q 'udp sport 547 udp dport 546 accept' packaging/nftables/obos.nft \
  || fail "DHCPv6 client renewals are not allowed"

! grep -q 'tcp dport 22 accept' packaging/nftables/obos.nft \
  || fail "SSH is open in the default firewall"

# shellcheck disable=SC2016
grep -Fq 'DISABLE_SSH="${OBOS_DISABLE_SSH:-1}"' scripts/hardening/apply-host-hardening.sh \
  || fail "SSH disablement is not the default hardening behavior"

# shellcheck disable=SC2016
grep -Fq 'APPLY_RUNTIME="${OBOS_APPLY_RUNTIME_HARDENING:-1}"' scripts/hardening/apply-host-hardening.sh \
  || fail "host hardening does not default to runtime application"

grep -q 'OBOS_APPLY_RUNTIME_HARDENING=0' scripts/images/build-rpi4-arm64-image.sh \
  || fail "Raspberry Pi image builder does not disable live hardening in the chroot"

grep -q 'systemctl enable nftables.service' scripts/hardening/apply-host-hardening.sh \
  || fail "host hardening does not enable nftables for target boot"

grep -q 'systemctl restart nftables.service' scripts/hardening/apply-host-hardening.sh \
  || fail "host hardening does not apply nftables at runtime"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing NoNewPrivileges"

grep -q 'Wants=network-online.target' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit does not wait for network-online"

grep -q 'After=local-fs.target network-online.target' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit ordering does not include network-online"

grep -q 'ProtectSystem=full' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing filesystem protection"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit is missing NoNewPrivileges"

grep -q 'Wants=network-online.target' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit does not wait for network-online"

grep -q 'After=network-online.target docker.service obos-first-boot.service' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit ordering does not include network-online"

grep -q 'Restart=on-failure' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit does not retry failed starts"

grep -q 'RestartSec=30s' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit restart delay is not bounded"

grep -q 'ProtectSystem=full' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit is missing filesystem protection"

grep -q 'ssl_certificate /etc/obos/tls/obos.local.crt;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not use obos TLS certificate"

grep -q 'proxy_pass http://127.0.0.1:8080;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not target localhost OBS"

grep -q 'location /obos/' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not expose obos-web path"

grep -q 'location /obos/api/' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not expose obos agent API path"

grep -q 'proxy_pass http://127.0.0.1:8091;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not target localhost obos agent HTTP bridge"

grep -q 'alias /srv/obos/web/;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not serve obos-web assets"

grep -q 'server_tokens off;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy exposes server tokens"

grep -q 'client_body_timeout 30s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound client body timeout"

grep -q 'client_header_timeout 30s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound client header timeout"

grep -q 'send_timeout 60s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound send timeout"

grep -q 'write_initramfs_modules' scripts/images/build-rpi4-arm64-image.sh \
  || fail "Raspberry Pi image builder does not force boot media modules into initramfs"

grep -q '^nvme$' scripts/images/build-rpi4-arm64-image.sh \
  || fail "Raspberry Pi image builder does not include NVMe in initramfs modules"

grep -q '^pcie-brcmstb$' scripts/images/build-rpi4-arm64-image.sh \
  || fail "Raspberry Pi image builder does not include Raspberry Pi PCIe in initramfs modules"

grep -q 'config_is_active' scripts/images/check-rpi-kernel-config.sh \
  || fail "Raspberry Pi kernel config check does not accept active module configs"

grep -q 'no-new-privileges:true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not set no-new-privileges"

grep -q 'init: true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not enable init process handling"

grep -q 'pids_limit: 128' apps/openbridgeserver/compose.yaml \
  || fail "Mosquitto container does not limit process count"

grep -q 'pids_limit: 256' apps/openbridgeserver/compose.yaml \
  || fail "open bridge server container does not limit process count"

grep -q 'TLS_DIR=' scripts/obosctl \
  || fail "obosctl backup does not know the TLS material directory"

grep -q 'backup includes TLS private key material' scripts/obosctl \
  || fail "obosctl backup does not warn about TLS private key material"

grep -q 'mqtt-enable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN enablement"

grep -q 'mqtt-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable MQTT status"

grep -q 'format=obos-mqtt-summary-v1' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not expose a summary format"

grep -q 'lan_enabled=' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT summary does not report LAN exposure"

grep -q 'firewall_source=' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT summary does not report firewall source scope"

grep -q 'mqtt-disable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN disablement"

grep -q 'basicConstraints=critical,CA:TRUE,pathlen:0' scripts/tls/generate-tls-material.sh \
  || fail "local CA is not generated with critical CA constraints"

grep -q 'TLS material already exists' scripts/tls/generate-tls-material.sh \
  || fail "TLS material generation is not idempotent"

grep -q 'ca_created' scripts/tls/generate-tls-material.sh \
  || fail "TLS idempotency does not account for CA regeneration"

grep -q 'tls-renew-leaf-plan)' scripts/obosctl \
  || fail "obosctl does not expose non-destructive TLS leaf renewal planning"

grep -q 'format=obos-tls-leaf-renewal-plan-v1' scripts/tls/plan-leaf-renewal.sh \
  || fail "TLS leaf renewal plan does not expose a summary format"

grep -q 'mode=non-destructive' scripts/tls/plan-leaf-renewal.sh \
  || fail "TLS leaf renewal plan must be non-destructive"

grep -q 'preserves_local_ca=true' scripts/tls/plan-leaf-renewal.sh \
  || fail "TLS leaf renewal plan must preserve the local CA"

grep -q 'client_reonboarding_required=false' scripts/tls/plan-leaf-renewal.sh \
  || fail "TLS leaf renewal plan must not require client re-onboarding"

grep -q 'live_change_allowed=false' scripts/tls/plan-leaf-renewal.sh \
  || fail "TLS leaf renewal plan must not perform a live change"

grep -q 'tls-renew-leaf)' scripts/obosctl \
  || fail "obosctl does not expose confirmed TLS leaf renewal"

grep -q -- '--confirm tls-renew-leaf' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal does not require explicit confirmation"

grep -q 'format=obos-tls-leaf-renewal-v1' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal does not expose a summary format"

grep -q 'backup_dir=' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal does not report the pre-change backup directory"

grep -q 'preserves_local_ca=true' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal must preserve the local CA"

grep -q 'client_reonboarding_required=false' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal must not require client re-onboarding"

grep -q 'trust_export_refreshed=' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal must refresh trust export when possible"

grep -q 'systemctl reload nginx.service' scripts/tls/renew-leaf-certificate.sh \
  || fail "TLS leaf renewal must reload nginx when active"

if grep -q 'action=tls-renew-leaf' scripts/agent/obos-agent.sh; then
  fail "TLS leaf renewal must remain CLI-only and not be exposed through obos-agent"
fi

if grep -q '"tls-renew-leaf"' scripts/agent/obos-agent-http.py; then
  fail "TLS leaf renewal must remain CLI-only and not be exposed through HTTP bridge"
fi

if grep -q 'data-mutation-action="tls-renew-leaf"' apps/obos-web/index.html; then
  fail "TLS leaf renewal must remain CLI-only and not be exposed through web UI"
fi

grep -q 'TLS leaf renewal is intentionally not exposed through the HTTP bridge or web UI' docs/web-ui-agent-contract.md \
  || fail "web UI agent contract does not document CLI-only TLS leaf renewal"

grep -q 'No private keys were exported.' scripts/tls/export-trust-bundle.sh \
  || fail "TLS trust export does not state that private keys are excluded"

grep -q 'tls-export)' scripts/obosctl \
  || fail "obosctl does not expose TLS trust export"

grep -q 'tls-status)' scripts/obosctl \
  || fail "obosctl does not expose TLS status checks"

grep -q 'tls-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable TLS trust status"

grep -q 'format=obos-tls-summary-v1' scripts/tls/check-tls-status.sh \
  || fail "TLS status helper does not expose a summary format"

grep -q 'trust_export_present=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report trust export presence"

grep -q 'trust_export_dir=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report trust export directory"

grep -q '_sha256_fingerprint=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report certificate fingerprints"

grep -q '_expiry_state=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report certificate expiry state"

grep -q 'tls-export-boot)' scripts/obosctl \
  || fail "obosctl does not expose boot trust summary export"

grep -q 'No private keys were exported to the boot partition.' scripts/tls/export-boot-trust-summary.sh \
  || fail "boot trust summary export does not state that private keys are excluded"

# shellcheck disable=SC2016
grep -q 'openssl x509 -in "${cert}" -noout -checkend' scripts/tls/check-tls-status.sh \
  || fail "TLS status helper does not check certificate expiry"
