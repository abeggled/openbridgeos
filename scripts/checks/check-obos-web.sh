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

grep -q 'data-agent-field="backup-summary:' "${INDEX}" \
  || fail "web UI does not expose backup summary placeholders"

grep -q 'data-agent-field="backup-list:backup_count"' "${INDEX}" \
  || fail "web UI does not expose backup inventory count"

grep -q 'data-agent-field="restore-stage-summary:' "${INDEX}" \
  || fail "web UI does not expose restore staging placeholders"

grep -q 'data-agent-field="mqtt-summary:' "${INDEX}" \
  || fail "web UI does not expose MQTT summary placeholders"

grep -q 'data-agent-field="tls-summary:' "${INDEX}" \
  || fail "web UI does not expose TLS summary placeholders"

grep -q 'data-agent-field="security-summary:' "${INDEX}" \
  || fail "web UI does not expose security summary placeholders"

grep -q 'data-agent-field="agent-audit-summary:' "${INDEX}" \
  || fail "web UI does not expose agent audit summary placeholders"

grep -q '<script src="./app.js" defer></script>' "${INDEX}" \
  || fail "web UI does not load app.js"

grep -q 'data-refresh-status' "${INDEX}" \
  || fail "web UI does not expose refresh control"

grep -q '/obos/api/v1/actions/' "${JS}" \
  || fail "web UI does not call the obos agent HTTP bridge"

grep -q 'parseAgentResponse' "${JS}" \
  || fail "web UI does not parse the agent response envelope"

grep -q 'data-agent-field' "${JS}" \
  || fail "web UI script does not target agent fields"

grep -q 'unsupportedActions' "${JS}" \
  || fail "web UI script does not keep unsupported actions explicit"

grep -q 'grid-template-columns' "${CSS}" \
  || fail "web UI CSS does not define stable grid layout"

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
