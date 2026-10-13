#!/usr/bin/env sh
set -eu

WEB_DIR="apps/obos-web"
ONBOARDING_DIR="apps/obos-onboarding"
INDEX="${WEB_DIR}/index.html"
CSS="${WEB_DIR}/styles.css"
JS="${WEB_DIR}/app.js"
ONBOARDING_INDEX="${ONBOARDING_DIR}/index.html"
ONBOARDING_CSS="${ONBOARDING_DIR}/styles.css"
ONBOARDING_JS="${ONBOARDING_DIR}/onboarding.js"

fail() {
  echo "obos-web check failed: $1" >&2
  exit 1
}

[ -f "${INDEX}" ] || fail "index.html missing"
[ -f "${CSS}" ] || fail "styles.css missing"
[ -f "${JS}" ] || fail "app.js missing"
[ -f "${ONBOARDING_INDEX}" ] || fail "onboarding UI index missing"
[ -f "${ONBOARDING_CSS}" ] || fail "onboarding UI styles missing"
[ -f "${ONBOARDING_JS}" ] || fail "onboarding UI script missing"

grep -q '<main class="shell" data-app-shell hidden>' "${INDEX}" \
  || fail "web UI does not define the appliance shell"

grep -q 'data-login-form' "${INDEX}" \
  || fail "web UI does not define a GUI login form"

grep -q 'data-logout' "${INDEX}" \
  || fail "web UI does not expose logout"

grep -q 'open bridge operating system' "${INDEX}" \
  || fail "web UI does not use product name"

grep -q 'data-agent-field="status-summary:' "${INDEX}" \
  || fail "web UI does not expose status summary placeholders"

grep -q 'data-agent-field="system-summary:hostname"' "${INDEX}" \
  || fail "web UI does not expose hostname"

grep -q 'data-agent-field="system-summary:timezone"' "${INDEX}" \
  || fail "web UI does not expose timezone"

grep -q 'id="host-name"' "${INDEX}" \
  || fail "web UI does not expose hostname input"

grep -q 'id="host-timezone"' "${INDEX}" \
  || fail "web UI does not expose timezone input"

grep -q 'id="host-domain"' "${INDEX}" \
  || fail "web UI does not expose optional host domain input"

grep -q 'list="timezone-options"' "${INDEX}" \
  || fail "web UI timezone input is not searchable"

grep -q 'data-mutation-action="set-hostname"' "${INDEX}" \
  || fail "web UI does not expose hostname mutation control"

grep -q 'data-confirm="set-hostname"' "${INDEX}" \
  || fail "web UI hostname mutation control does not carry confirmation token"

grep -q 'data-mutation-action="set-timezone"' "${INDEX}" \
  || fail "web UI does not expose timezone mutation control"

grep -q 'data-confirm="set-timezone"' "${INDEX}" \
  || fail "web UI timezone mutation control does not carry confirmation token"

grep -q 'data-mutation-status="host"' "${INDEX}" \
  || fail "web UI does not expose host mutation status"

grep -q 'data-agent-field="system-summary:default_route_present"' "${INDEX}" \
  || fail "web UI does not expose network route status"

grep -q 'data-agent-field="status-summary:service_active"' "${INDEX}" \
  || fail "web UI does not expose the systemd service state"

if grep -q 'status-summary:systemd_active' "${INDEX}"; then
  fail "web UI references a nonexistent systemd status field"
fi

grep -q 'data-agent-field="update-summary:rollback_backup_present"' "${INDEX}" \
  || fail "web UI does not expose update rollback readiness"

grep -q 'data-agent-field="update-summary:last_update_present"' "${INDEX}" \
  || fail "web UI does not expose last update state"

grep -q 'data-agent-field="backup-summary:' "${INDEX}" \
  || fail "web UI does not expose backup summary placeholders"

grep -q 'data-agent-field="backup-list:backup_count"' "${INDEX}" \
  || fail "web UI does not expose backup inventory count"

grep -q 'data-mutation-action="backup"' "${INDEX}" \
  || fail "web UI does not expose backup mutation control"

grep -q 'data-confirm="backup"' "${INDEX}" \
  || fail "web UI backup mutation control does not carry confirmation token"

grep -q 'data-mutation-status="backup"' "${INDEX}" \
  || fail "web UI does not expose backup mutation status"

grep -q 'id="portable-passphrase"' "${INDEX}" \
  || fail "web UI does not expose portable export passphrase input"

grep -q 'data-mutation-action="portable-export"' "${INDEX}" \
  || fail "web UI does not expose portable export mutation control"

grep -q 'data-confirm="portable-export"' "${INDEX}" \
  || fail "web UI portable export mutation control does not carry confirmation token"

grep -q 'data-portable-download' "${INDEX}" \
  || fail "web UI does not expose portable export download link"

grep -q 'data-agent-field="restore-stage-summary:' "${INDEX}" \
  || fail "web UI does not expose restore staging placeholders"

grep -q 'data-mutation-action="restore-stage"' "${INDEX}" \
  || fail "web UI does not expose restore-stage mutation control"

grep -q 'data-confirm="restore-stage"' "${INDEX}" \
  || fail "web UI restore-stage mutation control does not carry confirmation token"

grep -q 'data-mutation-backup-from="backup-summary:latest_backup"' "${INDEX}" \
  || fail "web UI restore-stage mutation does not use latest backup source"

grep -q 'data-mutation-status="restore-stage"' "${INDEX}" \
  || fail "web UI does not expose restore-stage mutation status"

grep -q 'id="portable-import-file"' "${INDEX}" \
  || fail "web UI does not expose portable import file input"

grep -q 'data-upload-portable' "${INDEX}" \
  || fail "web UI does not expose portable import upload control"

grep -q 'id="portable-import-passphrase"' "${INDEX}" \
  || fail "web UI does not expose portable import passphrase input"

grep -q 'data-mutation-action="portable-import-stage"' "${INDEX}" \
  || fail "web UI does not expose portable import staging control"

grep -q 'data-mutation-portable-from="portable-import-upload:portable_backup"' "${INDEX}" \
  || fail "web UI portable import staging does not use uploaded portable backup"

grep -q 'data-agent-field="mqtt-summary:' "${INDEX}" \
  || fail "web UI does not expose MQTT summary placeholders"

grep -q 'data-agent-field="mqtt-summary:mqtt_host_port"' "${INDEX}" \
  || fail "web UI does not expose the MQTT plain listener"

grep -q 'data-agent-field="mqtt-summary:mqtt_ws_host_port"' "${INDEX}" \
  || fail "web UI does not expose the MQTT websocket listener"

grep -q 'data-agent-field="mqtt-summary:firewall_source"' "${INDEX}" \
  || fail "web UI does not expose the MQTT firewall source"

grep -q 'id="mqtt-source-cidr"' "${INDEX}" \
  || fail "web UI does not expose MQTT source CIDR input"

grep -q 'data-mutation-action="mqtt-enable-lan"' "${INDEX}" \
  || fail "web UI does not expose MQTT enable mutation control"

grep -q 'data-confirm="mqtt-enable-lan"' "${INDEX}" \
  || fail "web UI MQTT enable mutation control does not carry confirmation token"

grep -q 'data-mutation-action="mqtt-disable-lan"' "${INDEX}" \
  || fail "web UI does not expose MQTT disable mutation control"

grep -q 'data-confirm="mqtt-disable-lan"' "${INDEX}" \
  || fail "web UI MQTT disable mutation control does not carry confirmation token"

grep -q 'data-mutation-status="mqtt"' "${INDEX}" \
  || fail "web UI does not expose MQTT mutation status"

grep -q 'data-agent-field="tls-summary:' "${INDEX}" \
  || fail "web UI does not expose TLS summary placeholders"

grep -q 'data-agent-field="tls-summary:local_ca_present"' "${INDEX}" \
  || fail "web UI does not expose local CA presence"

grep -q 'data-agent-field="tls-summary:local_ca_sha256_fingerprint"' "${INDEX}" \
  || fail "web UI does not expose local CA fingerprint"

grep -q 'data-agent-field="tls-summary:leaf_sha256_fingerprint"' "${INDEX}" \
  || fail "web UI does not expose leaf certificate fingerprint"

grep -q 'data-agent-field="tls-summary:leaf_not_after"' "${INDEX}" \
  || fail "web UI does not expose the leaf certificate expiry date"

grep -q 'data-agent-field="tls-summary:leaf_dns_names"' "${INDEX}" \
  || fail "web UI does not expose leaf DNS SANs"

grep -q 'data-agent-field="tls-summary:leaf_ip_addresses"' "${INDEX}" \
  || fail "web UI does not expose leaf IP SANs"

grep -q 'data-host-identity-tls-notice' "${INDEX}" \
  || fail "web UI does not expose the host identity certificate mismatch notice"

grep -q 'data-agent-field="tls-summary:leaf_validity_days"' "${INDEX}" \
  || fail "web UI does not expose the leaf validity policy"

grep -q 'data-agent-field="tls-summary:leaf_renew_after_days"' "${INDEX}" \
  || fail "web UI does not expose the automatic renewal age"

grep -q 'updateHostIdentityTlsNotice' "${JS}" \
  || fail "web UI does not reconcile host identity with leaf DNS names"

grep -q 'data-mutation-action="tls-renew-leaf"' "${INDEX}" \
  || fail "web UI does not expose confirmed leaf renewal"

if grep -Eq 'data-mutation-action="tls-(generate|export)"' "${INDEX}"; then
  fail "web UI exposes automatic TLS initialization or export as manual controls"
fi

grep -q 'data-mutation-status="tls"' "${INDEX}" \
  || fail "web UI does not expose TLS mutation status"

grep -q 'data-ca-download' "${INDEX}" \
  || fail "web UI does not expose the exported Root CA download"

grep -q 'data-help-dialog' "${INDEX}" \
  || fail "web UI does not define contextual help overlay"

grep -q 'data-help-title' "${INDEX}" \
  || fail "web UI does not expose contextual help controls"

grep -q 'data-agent-field="security-summary:' "${INDEX}" \
  || fail "web UI does not expose security summary placeholders"

grep -q 'data-agent-field="agent-audit-summary:' "${INDEX}" \
  || fail "web UI does not expose agent audit summary placeholders"

grep -q 'data-agent-field="mvp-readiness-summary:result"' "${INDEX}" \
  || fail "web UI does not expose MVP readiness result"

grep -q 'data-agent-field="mvp-readiness-summary:pass_count"' "${INDEX}" \
  || fail "web UI does not expose MVP readiness pass count"

grep -q 'data-agent-field="mvp-readiness-summary:fail_count"' "${INDEX}" \
  || fail "web UI does not expose MVP readiness fail count"

grep -q 'data-run-mvp-readiness' "${INDEX}" \
  || fail "web UI does not expose MVP readiness refresh control"

grep -q 'data-run-security-audit' "${INDEX}" \
  || fail "web UI does not expose security audit refresh control"

grep -q 'data-security-failure-details hidden' "${INDEX}" \
  || fail "web UI does not expose hidden security failure details"

grep -q 'data-mvp-failure-details hidden' "${INDEX}" \
  || fail "web UI does not expose hidden MVP failure details"

grep -q 'function renderFailures' "${JS}" \
  || fail "web UI does not render individual failed checks"

grep -Fq '/^failure_\d+$/' "${JS}" \
  || fail "web UI does not restrict detail rendering to failure records"

grep -q 'data-mutation-action="web-auth-rotate"' "${INDEX}" \
  || fail "web UI does not expose web auth rotation control"

grep -q 'data-confirm="web-auth-rotate"' "${INDEX}" \
  || fail "web UI web auth rotation control does not carry confirmation token"

grep -q 'data-mutation-status="web-auth"' "${INDEX}" \
  || fail "web UI does not expose web auth rotation status"

grep -q 'data-web-auth-password' "${INDEX}" \
  || fail "web UI does not expose one-time rotated password output"

grep -q 'data-web-auth-secret hidden' "${INDEX}" \
  || fail "web UI rotated password output is not hidden by default"

grep -q 'data-clear-web-auth-password' "${INDEX}" \
  || fail "web UI does not allow immediate password dismissal"

grep -q 'data-agent-field="logs-summary:raw_logs_exposed"' "${INDEX}" \
  || fail "web UI does not expose log exposure status"

grep -q 'data-agent-field="logs-summary:bounded_logs_exposed"' "${INDEX}" \
  || fail "web UI does not expose bounded log availability"

grep -q 'data-agent-field="logs-summary:journal_entry_count_last_hour"' "${INDEX}" \
  || fail "web UI does not expose recent journal entry count"

grep -q 'data-load-logs' "${INDEX}" \
  || fail "web UI does not expose bounded log loading control"

grep -q 'data-log-output' "${INDEX}" \
  || fail "web UI does not expose bounded log output"

grep -q '<script src="./app.js" defer></script>' "${INDEX}" \
  || fail "web UI does not load app.js"

grep -q 'data-refresh-status' "${INDEX}" \
  || fail "web UI does not expose refresh control"

grep -q 'data-mutation-action="start"' "${INDEX}" \
  || fail "web UI does not expose start mutation control"

grep -q 'data-mutation-action="stop"' "${INDEX}" \
  || fail "web UI does not expose stop mutation control"

grep -q 'data-mutation-action="restart"' "${INDEX}" \
  || fail "web UI does not expose restart mutation control"

grep -q 'data-mutation-action="update"' "${INDEX}" \
  || fail "web UI does not expose update mutation control"

grep -q 'data-mutation-status="service-action"' "${INDEX}" \
  || fail "web UI does not expose service mutation status"

grep -q '/obos/api/v1/actions/' "${JS}" \
  || fail "web UI does not call the obos agent HTTP bridge"

grep -q '/obos/api/v1/session/' "${JS}" \
  || fail "web UI does not call the GUI session API"

grep -q 'data-auth-screen' "${INDEX}" \
  || fail "web UI does not define an auth screen"

grep -Fq '[hidden]' "${CSS}" \
  || fail "web UI CSS does not preserve hidden element state"

grep -Fq 'display: none !important;' "${CSS}" \
  || fail "web UI CSS can override hidden element state"

grep -q 'AbortController' "${JS}" \
  || fail "web UI session requests do not have a bounded timeout"

[ "$(grep -Fc 'void refresh();' "${JS}")" -ge 2 ] \
  || fail "web UI login and session checks wait on background status refreshes"

grep -q 'parseAgentResponse' "${JS}" \
  || fail "web UI does not parse the agent response envelope"

grep -q 'agentStdoutLines' "${JS}" \
  || fail "web UI does not parse agent stdout lines"

grep -q 'logs-tail' "${JS}" \
  || fail "web UI does not request bounded log tail"

grep -q 'renderLogs' "${JS}" \
  || fail "web UI does not render bounded log output"

grep -q 'data-agent-field' "${JS}" \
  || fail "web UI script does not target agent fields"

grep -q 'unsupportedActions' "${JS}" \
  || fail "web UI script does not keep unsupported actions explicit"

grep -q 'runMutation' "${JS}" \
  || fail "web UI script does not handle confirmed mutations"

grep -q 'Content-Type": "application/json"' "${JS}" \
  || fail "web UI mutations do not use JSON requests"

grep -q 'JSON.stringify(body)' "${JS}" \
  || fail "web UI mutations do not send confirmation token"

grep -q 'mutationStatusTarget' "${JS}" \
  || fail "web UI mutations do not route status to explicit targets"

grep -q 'mutationBackupFrom' "${JS}" \
  || fail "web UI restore-stage mutation does not read backup source"

grep -q 'body.backup_path = backupPath' "${JS}" \
  || fail "web UI restore-stage mutation does not send backup path"

grep -q 'downloadBase = "/obos/api/v1/downloads/"' "${JS}" \
  || fail "web UI does not know the portable export download base"

grep -q 'uploadBase = "/obos/api/v1/uploads/"' "${JS}" \
  || fail "web UI does not know the portable import upload base"

grep -q 'setPortableDownload' "${JS}" \
  || fail "web UI does not prepare portable export downloads"

grep -q 'uploadPortableImport' "${JS}" \
  || fail "web UI does not upload portable imports"

grep -q 'body.passphrase = passphrase' "${JS}" \
  || fail "web UI portable export mutation does not send passphrase"

grep -q 'body.portable_backup = portablePath' "${JS}" \
  || fail "web UI portable import staging does not send uploaded portable path"

grep -q 'mqtt-enable-lan' "${JS}" \
  || fail "web UI does not handle MQTT enable mutation body"

grep -q 'body.source_cidr = cidr' "${JS}" \
  || fail "web UI does not send optional MQTT source CIDR"

grep -q 'body.hostname = domain' "${JS}" \
  || fail "web UI does not form the hostname mutation payload with an optional domain"

grep -q 'Intl.supportedValuesOf' "${JS}" \
  || fail "web UI does not populate searchable timezone choices"

grep -q 'body.timezone = timezone' "${JS}" \
  || fail "web UI does not send timezone mutation payload"

grep -q 'runSecurityAudit' "${JS}" \
  || fail "web UI does not handle security audit refresh"

grep -q 'runMvpReadiness' "${JS}" \
  || fail "web UI does not handle MVP readiness refresh"

grep -q 'refreshReadOnlyActions' "${JS}" \
  || fail "web UI does not share read-only action refresh handling"

grep -q 'mvp-readiness-summary' "${JS}" \
  || fail "web UI does not refresh MVP readiness fields"

grep -q 'security-summary", "agent-audit-summary' "${JS}" \
  || fail "web UI security audit refresh does not target security fields"

grep -q 'setWebAuthPassword' "${JS}" \
  || fail "web UI does not render rotated web auth password"

grep -q 'window.setTimeout(clearWebAuthPassword, 60000)' "${JS}" \
  || fail "web UI does not clear the rotated password after one minute"

grep -q 'clearWebAuthPasswordButton' "${JS}" \
  || fail "web UI does not wire rotated password dismissal"

grep -q 'action === "web-auth-rotate"' "${JS}" \
  || fail "web UI does not handle web auth rotation response"

grep -q 'grid-template-columns' "${CSS}" \
  || fail "web UI CSS does not define stable grid layout"

grep -q '.secret-value' "${CSS}" \
  || fail "web UI CSS does not style secret output"

grep -q '.button-row' "${CSS}" \
  || fail "web UI CSS does not define action button row layout"

grep -q '.download-link' "${CSS}" \
  || fail "web UI CSS does not style portable download link"

grep -q '.help-button' "${CSS}" \
  || fail "web UI CSS does not style compact help controls"

grep -q '.help-dialog' "${CSS}" \
  || fail "web UI CSS does not style the help overlay"

grep -q 'helpDialog.showModal()' "${JS}" \
  || fail "web UI does not open contextual help overlay"

if grep -q 'action === "tls-export"' "${JS}"; then
  fail "web UI retains unreachable manual TLS export handling"
fi

grep -q '^input {' "${CSS}" \
  || fail "web UI CSS does not style input controls"

grep -q '.log-viewer' "${CSS}" \
  || fail "web UI CSS does not define bounded log viewer"

grep -q 'border-radius: var(--radius)' "${CSS}" \
  || fail "web UI CSS does not use bounded card radius"

grep -q 'OBOS_WEB_DIR="/srv/obos/web"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not define the obos-web install directory"

grep -q 'OBOS_ONBOARDING_DIR="/srv/obos/onboarding"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not define the onboarding UI install directory"

# shellcheck disable=SC2016
grep -q 'install -d -m 0755 "${OBOS_WEB_DIR}"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not create the obos-web install directory"

grep -q 'install -d -m 0750 -g www-data /srv/obos' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not allow nginx to traverse /srv/obos"

grep -Fq 'width: min(100%, 560px);' apps/obos-web/styles.css \
  || fail "obos-web login panel does not use the wider responsive layout"

grep -Fq 'width: min(100%, 560px);' apps/obos-onboarding/styles.css \
  || fail "obos onboarding panel does not use the wider responsive layout"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/index.html" "${OBOS_WEB_DIR}/index.html"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web index"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/styles.css" "${OBOS_WEB_DIR}/styles.css"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web styles"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/app.js" "${OBOS_WEB_DIR}/app.js"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web script"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-onboarding/index.html" "${OBOS_ONBOARDING_DIR}/index.html"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install onboarding index"

grep -q '/obos/api/v1/onboarding/status' "${ONBOARDING_JS}" \
  || fail "onboarding UI does not check onboarding status"

grep -q '/obos/api/v1/onboarding/web-auth' "${ONBOARDING_JS}" \
  || fail "onboarding UI does not set the initial web password"

grep -q 'location \^~ /obos/' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not expose obos-web under /obos/"

grep -q 'location \^~ /obos/onboarding/' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not expose onboarding UI under /obos/onboarding/"

grep -q 'root /srv/obos/onboarding;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not serve onboarding index directly"

grep -q 'try_files /onboarding.js =404;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not serve onboarding UI from /srv/obos/onboarding"

if grep -q 'auth_basic "open bridge operating system";' packaging/nginx/openbridgeserver.conf; then
  fail "nginx must not use browser Basic Auth for obos-web"
fi

grep -q 'root /srv/obos/web;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not serve obos-web index directly"

grep -q 'try_files /app.js =404;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not serve obos-web from /srv/obos/web"

grep -Fq 'add_header Cache-Control "no-store" always;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx allows stale web application assets"

if grep -q 'alias /srv/obos/' packaging/nginx/openbridgeserver.conf; then
  fail "nginx must not use prefix alias for obos static files"
fi

grep -q 'return 404;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not reject unknown obos static paths"

grep -q 'auth_request /_obos_obs_access;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not gate OBS access on completed onboarding"

grep -q 'proxy_pass http://127.0.0.1:8091/obos/api/v1/onboarding/access;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx onboarding access gate is not backed by the local agent"

grep -q 'error_page 401 403 = @obos_onboarding_required;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not redirect blocked OBS requests to onboarding"

grep -q 'ConditionPathExists=/etc/obos/web.htpasswd' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server service can start before onboarding credentials exist"

# shellcheck disable=SC2016
grep -q 'systemctl start --no-block "${SERVICE_NAME}"' scripts/obosctl \
  || fail "completed onboarding does not start open bridge server"

grep -q 'window.location.replace("/obos/")' "${ONBOARDING_JS}" \
  || fail "completed onboarding does not redirect immediately to login"

grep -q 'mutationErrorMessage' "${JS}" \
  || fail "web UI does not expose actionable mutation errors"

echo "obos-web: PASS"
