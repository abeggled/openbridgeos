#!/usr/bin/env sh
set -eu

WEB_DIR="apps/obos-web"
INDEX="${WEB_DIR}/index.html"
CSS="${WEB_DIR}/styles.css"
JS="${WEB_DIR}/app.js"

fail() {
  echo "obos-web check failed: $1" >&2
  exit 1
}

[ -f "${INDEX}" ] || fail "index.html missing"
[ -f "${CSS}" ] || fail "styles.css missing"
[ -f "${JS}" ] || fail "app.js missing"

grep -q '<main class="shell">' "${INDEX}" \
  || fail "web UI does not define the appliance shell"

grep -q 'open bridge operating system' "${INDEX}" \
  || fail "web UI does not use product name"

grep -q 'data-agent-field="status-summary:' "${INDEX}" \
  || fail "web UI does not expose status summary placeholders"

grep -q 'data-agent-field="system-summary:hostname"' "${INDEX}" \
  || fail "web UI does not expose hostname"

grep -q 'data-agent-field="system-summary:timezone"' "${INDEX}" \
  || fail "web UI does not expose timezone"

grep -q 'data-agent-field="system-summary:default_route_present"' "${INDEX}" \
  || fail "web UI does not expose network route status"

grep -q 'data-agent-field="update-rollback-plan:backup_present"' "${INDEX}" \
  || fail "web UI does not expose update rollback planning state"

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

grep -q 'data-agent-field="mqtt-summary:' "${INDEX}" \
  || fail "web UI does not expose MQTT summary placeholders"

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

grep -q 'data-agent-field="tls-summary:local_ca_sha256_fingerprint"' "${INDEX}" \
  || fail "web UI does not expose local CA fingerprint"

grep -q 'data-agent-field="tls-summary:leaf_sha256_fingerprint"' "${INDEX}" \
  || fail "web UI does not expose leaf certificate fingerprint"

grep -q 'data-agent-field="tls-summary:leaf_expiry_warning"' "${INDEX}" \
  || fail "web UI does not expose leaf certificate expiry warning"

grep -q 'data-mutation-action="tls-generate"' "${INDEX}" \
  || fail "web UI does not expose TLS generate mutation control"

grep -q 'data-confirm="tls-generate"' "${INDEX}" \
  || fail "web UI TLS generate mutation control does not carry confirmation token"

grep -q 'data-mutation-action="tls-export"' "${INDEX}" \
  || fail "web UI does not expose TLS export mutation control"

grep -q 'data-confirm="tls-export"' "${INDEX}" \
  || fail "web UI TLS export mutation control does not carry confirmation token"

grep -q 'data-mutation-status="tls"' "${INDEX}" \
  || fail "web UI does not expose TLS mutation status"

grep -q 'data-agent-field="security-summary:' "${INDEX}" \
  || fail "web UI does not expose security summary placeholders"

grep -q 'data-agent-field="agent-audit-summary:' "${INDEX}" \
  || fail "web UI does not expose agent audit summary placeholders"

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

grep -q 'mqtt-enable-lan' "${JS}" \
  || fail "web UI does not handle MQTT enable mutation body"

grep -q 'body.source_cidr = cidr' "${JS}" \
  || fail "web UI does not send optional MQTT source CIDR"

grep -q 'grid-template-columns' "${CSS}" \
  || fail "web UI CSS does not define stable grid layout"

grep -q '.button-row' "${CSS}" \
  || fail "web UI CSS does not define action button row layout"

grep -q '^input {' "${CSS}" \
  || fail "web UI CSS does not style input controls"

grep -q '.log-viewer' "${CSS}" \
  || fail "web UI CSS does not define bounded log viewer"

grep -q 'border-radius: var(--radius)' "${CSS}" \
  || fail "web UI CSS does not use bounded card radius"

grep -q 'OBOS_WEB_DIR="/srv/obos/web"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not define the obos-web install directory"

# shellcheck disable=SC2016
grep -q 'install -d -m 0755 "${OBOS_WEB_DIR}"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not create the obos-web install directory"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/index.html" "${OBOS_WEB_DIR}/index.html"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web index"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/styles.css" "${OBOS_WEB_DIR}/styles.css"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web styles"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/apps/obos-web/app.js" "${OBOS_WEB_DIR}/app.js"' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install obos-web script"

grep -q 'location /obos/' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not expose obos-web under /obos/"

grep -q 'alias /srv/obos/web/;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not serve obos-web from /srv/obos/web"

grep -q 'try_files .* /obos/index.html;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx does not fall back to obos-web index"

echo "obos-web: PASS"
