#!/usr/bin/env sh
set -eu

BRIDGE="scripts/agent/obos-agent-http.py"
SERVICE="packaging/systemd/obos-agent-http.service"
NGINX_CONF="packaging/nginx/openbridgeserver.conf"
PYTHON_BIN="${PYTHON_BIN:-python3}"

fail() {
  echo "obos-agent-http check failed: $1" >&2
  exit 1
}

[ -f "${BRIDGE}" ] || fail "HTTP bridge script missing"
[ -f "${SERVICE}" ] || fail "HTTP bridge systemd unit missing"

"${PYTHON_BIN}" -m py_compile "${BRIDGE}" \
  || fail "HTTP bridge Python syntax failed"

grep -q 'READ_ONLY_ACTIONS' "${BRIDGE}" \
  || fail "read-only action allowlist missing"
grep -q 'MUTATING_ACTIONS' "${BRIDGE}" \
  || fail "mutating action allowlist missing"
grep -q '"backup": "backup"' "${BRIDGE}" \
  || fail "backup mutation is not exposed with a matching confirmation token"
grep -q '"portable-export": "portable-export"' "${BRIDGE}" \
  || fail "portable-export mutation is not exposed with a matching confirmation token"
grep -q '"portable-import-stage": "portable-import-stage"' "${BRIDGE}" \
  || fail "portable-import-stage mutation is not exposed with a matching confirmation token"
grep -q '"mqtt-enable-lan": "mqtt-enable-lan"' "${BRIDGE}" \
  || fail "mqtt-enable-lan mutation is not exposed with a matching confirmation token"
grep -q '"mqtt-disable-lan": "mqtt-disable-lan"' "${BRIDGE}" \
  || fail "mqtt-disable-lan mutation is not exposed with a matching confirmation token"
grep -q '"start": "start"' "${BRIDGE}" \
  || fail "start mutation is not exposed with a matching confirmation token"
grep -q '"stop": "stop"' "${BRIDGE}" \
  || fail "stop mutation is not exposed with a matching confirmation token"
grep -q '"restart": "restart"' "${BRIDGE}" \
  || fail "restart mutation is not exposed with a matching confirmation token"
grep -q '"restore-stage": "restore-stage"' "${BRIDGE}" \
  || fail "restore-stage mutation is not exposed with a matching confirmation token"
grep -q '"set-hostname": "set-hostname"' "${BRIDGE}" \
  || fail "set-hostname mutation is not exposed with a matching confirmation token"
grep -q '"set-timezone": "set-timezone"' "${BRIDGE}" \
  || fail "set-timezone mutation is not exposed with a matching confirmation token"
grep -q '"tls-generate": "tls-generate"' "${BRIDGE}" \
  || fail "tls-generate mutation is not exposed with a matching confirmation token"
grep -q '"tls-export": "tls-export"' "${BRIDGE}" \
  || fail "tls-export mutation is not exposed with a matching confirmation token"
grep -q '"update": "update"' "${BRIDGE}" \
  || fail "update mutation is not exposed with a matching confirmation token"
grep -q '"system-summary"' "${BRIDGE}" \
  || fail "system-summary is not exposed by the read-only HTTP bridge"
grep -q '"backup-list"' "${BRIDGE}" \
  || fail "backup-list is not exposed by the read-only HTTP bridge"
grep -q '"logs-summary"' "${BRIDGE}" \
  || fail "logs-summary is not exposed by the read-only HTTP bridge"
grep -q '"logs-tail"' "${BRIDGE}" \
  || fail "logs-tail is not exposed by the read-only HTTP bridge"
grep -q '"update-rollback-plan"' "${BRIDGE}" \
  || fail "update-rollback-plan is not exposed by the read-only HTTP bridge"
grep -q 'OBOS_AGENT_PATH' "${BRIDGE}" \
  || fail "agent path is not configurable"
grep -q '127.0.0.1' "${BRIDGE}" \
  || fail "bridge does not enforce loopback binding"
grep -q 'subprocess.run' "${BRIDGE}" \
  || fail "bridge does not call obos-agent as a subprocess"
grep -q '\[AGENT_PATH, \*args\]' "${BRIDGE}" \
  || fail "bridge does not avoid shell command construction"
grep -q 'do_POST' "${BRIDGE}" \
  || fail "bridge does not explicitly handle POST"
grep -q 'mutations-disabled' "${BRIDGE}" \
  || fail "bridge does not reject HTTP mutations"
grep -q 'application/json' "${BRIDGE}" \
  || fail "bridge does not require JSON for mutations"
grep -q 'MAX_POST_BYTES = 1024' "${BRIDGE}" \
  || fail "bridge does not limit mutation body size"
grep -q 'expected_fields = {"confirm"}' "${BRIDGE}" \
  || fail "bridge does not reject unexpected mutation body fields"
grep -q 'backup_path' "${BRIDGE}" \
  || fail "bridge does not support checked restore-stage backup path payload"
grep -q 'passphrase' "${BRIDGE}" \
  || fail "bridge does not support portable export passphrase payload"
grep -q 'DOWNLOAD_PREFIX = "/obos/api/v1/downloads/portable-export"' "${BRIDGE}" \
  || fail "bridge does not define the portable export download endpoint"
grep -q 'UPLOAD_PREFIX = "/obos/api/v1/uploads/portable-import"' "${BRIDGE}" \
  || fail "bridge does not define the portable import upload endpoint"
grep -q 'PORTABLE_EXPORT_DIR' "${BRIDGE}" \
  || fail "bridge does not restrict portable export downloads to an export directory"
grep -q 'Content-Disposition' "${BRIDGE}" \
  || fail "bridge does not send portable exports as attachments"
grep -q 'source_cidr' "${BRIDGE}" \
  || fail "bridge does not support optional MQTT source CIDR payload"
grep -q 'hostname' "${BRIDGE}" \
  || fail "bridge does not support hostname mutation payload"
grep -q 'timezone' "${BRIDGE}" \
  || fail "bridge does not support timezone mutation payload"
grep -q 'obos-agent-http-error-v1' "${BRIDGE}" \
  || fail "HTTP error envelope missing"
if grep -q 'Access-Control-Allow-Origin' "${BRIDGE}"; then
  fail "bridge must not emit CORS wildcard headers"
fi

grep -q 'User=obos-agent' "${SERVICE}" \
  || fail "HTTP bridge does not run as obos-agent"
grep -q 'OBOS_AGENT_HTTP_BIND=127.0.0.1' "${SERVICE}" \
  || fail "HTTP bridge service is not loopback-only"
grep -q 'ProtectSystem=strict' "${SERVICE}" \
  || fail "HTTP bridge service lacks strict filesystem protection"
grep -q 'MemoryDenyWriteExecute=true' "${SERVICE}" \
  || fail "HTTP bridge service lacks memory hardening"
if grep -q 'NoNewPrivileges=true' "${SERVICE}"; then
  fail "HTTP bridge service must not enable NoNewPrivileges while obos-agent uses sudo"
fi

grep -q 'location /obos/api/' "${NGINX_CONF}" \
  || fail "nginx does not expose the agent API path"
grep -q 'proxy_pass http://127.0.0.1:8091;' "${NGINX_CONF}" \
  || fail "nginx does not proxy the API path to the loopback bridge"
# shellcheck disable=SC2016
grep -q 'install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent-http.py" "${OBOS_LIB_DIR}/obos-agent-http.py' scripts/bootstrap/provision-debian.sh \
  || fail "HTTP bridge is not installed during provisioning"
grep -q 'python3-minimal' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install Python runtime for HTTP bridge"
grep -q 'obos-agent-http.service' scripts/bootstrap/provision-debian.sh \
  || fail "HTTP bridge service is not provisioned"

tmp_dir="$(mktemp -d)"
portable_export_dir="/tmp/obos-portable-exports"
portable_import_dir="/tmp/obos-portable-imports"
trap 'if [ -n "${server_pid:-}" ]; then kill "${server_pid}" 2>/dev/null || true; fi; rm -rf "${tmp_dir}" "${portable_export_dir}" "${portable_import_dir}"' EXIT

cat > "${tmp_dir}/obos-agent" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  status-summary)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=status-summary
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-status-summary-v1
stdout=service_active=true
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  system-summary)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=system-summary
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-system-summary-v1
stdout=hostname=obos-test
stdout=default_route_present=true
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  backup-list)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=backup-list
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-backup-list-v1
stdout=backup_count=2
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  update-rollback-plan)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=update-rollback-plan
exit_code=0
timed_out=false
stdout_begin
stdout=update rollback plan: /srv/obos/backups/obos-openbridgeserver-test.tar.gz
stdout=format=obos-update-rollback-plan-v1
stdout=backup_present=true
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  logs-summary)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=logs-summary
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-logs-summary-v1
stdout=raw_logs_exposed=false
stdout=journal_entry_count_last_hour=0
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  logs-tail)
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=logs-tail
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-logs-tail-v1
stdout=log=journal|test log line
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  backup)
    [ "${2:-}" = "--confirm" ] && [ "${3:-}" = "backup" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=backup
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-backup-v1
stdout=backup_path=/srv/obos/backups/obos-openbridgeserver-test.tar.gz
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  portable-export)
    [ "${2:-}" = "/srv/obos/backups/obos-openbridgeserver-test.tar.gz" ] || exit 2
    [ -n "${3:-}" ] && [ -f "${3:-}" ] || exit 2
    [ "${4:-}" = "--confirm" ] && [ "${5:-}" = "portable-export" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=portable-export
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-portable-backup-export-v1
stdout=portable_backup=/tmp/obos-portable-exports/obos-portable-test.tar
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  portable-import-stage)
    [ "${2:-}" = "/tmp/obos-portable-imports/obos-portable-upload-test.tar" ] || exit 2
    [ -n "${3:-}" ] && [ -f "${3:-}" ] || exit 2
    [ "${4:-}" = "--confirm" ] && [ "${5:-}" = "portable-import-stage" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=portable-import-stage
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-portable-import-stage-v1
stdout=restore_inspection=pass
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  start|stop|restart|update)
    [ "${2:-}" = "--confirm" ] && [ "${3:-}" = "${1:-}" ] || exit 2
    cat <<RESPONSE
format=obos-agent-response-v1
action=${1:-}
exit_code=0
timed_out=false
stdout_begin
stdout=${1:-}:ok
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  restore-stage)
    [ "${2:-}" = "/srv/obos/backups/obos-openbridgeserver-test.tar.gz" ] || exit 2
    [ "${3:-}" = "--confirm" ] && [ "${4:-}" = "restore-stage" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=restore-stage
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-restore-stage-v1
stdout=stage_dir=/srv/obos/state/restore-staging/restore.test
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  mqtt-enable-lan)
    if [ "${2:-}" = "--confirm" ]; then
      [ "${3:-}" = "mqtt-enable-lan" ] || exit 2
      cidr="any"
    else
      cidr="${2:-missing}"
      [ "${3:-}" = "--confirm" ] && [ "${4:-}" = "mqtt-enable-lan" ] || exit 2
    fi
    cat <<RESPONSE
format=obos-agent-response-v1
action=mqtt-enable-lan
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-mqtt-summary-v1
stdout=source_cidr=${cidr}
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  mqtt-disable-lan)
    [ "${2:-}" = "--confirm" ] && [ "${3:-}" = "mqtt-disable-lan" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=mqtt-disable-lan
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-mqtt-summary-v1
stdout=lan_enabled=false
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  tls-generate|tls-export)
    [ "${2:-}" = "--confirm" ] && [ "${3:-}" = "${1:-}" ] || exit 2
    cat <<RESPONSE
format=obos-agent-response-v1
action=${1:-}
exit_code=0
timed_out=false
stdout_begin
stdout=${1:-}:ok
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  set-hostname)
    [ "${2:-}" = "obos-test" ] || exit 2
    [ "${3:-}" = "--confirm" ] && [ "${4:-}" = "set-hostname" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=set-hostname
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-set-hostname-v1
stdout=hostname=obos-test
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  set-timezone)
    [ "${2:-}" = "Europe/Zurich" ] || exit 2
    [ "${3:-}" = "--confirm" ] && [ "${4:-}" = "set-timezone" ] || exit 2
    cat <<'RESPONSE'
format=obos-agent-response-v1
action=set-timezone
exit_code=0
timed_out=false
stdout_begin
stdout=format=obos-set-timezone-v1
stdout=timezone=Europe/Zurich
stdout_end
stderr_begin
stderr_end
RESPONSE
    ;;
  *)
    echo "unexpected action: ${1:-missing}" >&2
    exit 2
    ;;
esac
EOF
chmod 0755 "${tmp_dir}/obos-agent"
mkdir -p "${portable_export_dir}"
printf 'encrypted portable fixture\n' > "${portable_export_dir}/obos-portable-test.tar"
mkdir -p "${portable_import_dir}"

OBOS_AGENT_PATH="${tmp_dir}/obos-agent" \
OBOS_AGENT_HTTP_BIND=127.0.0.1 \
OBOS_AGENT_HTTP_PORT=18091 \
OBOS_PORTABLE_EXPORT_DIR=/tmp/obos-portable-exports \
OBOS_PORTABLE_IMPORT_DIR=/tmp/obos-portable-imports \
"${PYTHON_BIN}" "${BRIDGE}" &
server_pid="$!"

sleep 1

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/status-summary |
  grep -q 'stdout=format=obos-status-summary-v1' \
  || fail "HTTP bridge did not return agent response"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/system-summary |
  grep -q 'stdout=hostname=obos-test' \
  || fail "HTTP bridge did not expose system summary"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/backup-list |
  grep -q 'stdout=backup_count=2' \
  || fail "HTTP bridge did not expose backup inventory"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/update-rollback-plan |
  grep -q 'stdout=backup_present=true' \
  || fail "HTTP bridge did not expose update rollback plan"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/logs-summary |
  grep -q 'stdout=raw_logs_exposed=false' \
  || fail "HTTP bridge did not expose metadata-only logs summary"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/logs-tail |
  grep -q 'stdout=log=journal|test log line' \
  || fail "HTTP bridge did not expose bounded logs tail"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"backup"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/backup |
  grep -q 'stdout=format=obos-backup-v1' \
  || fail "HTTP bridge did not run confirmed backup mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"portable-export","backup_path":"/srv/obos/backups/obos-openbridgeserver-test.tar.gz","passphrase":"test-passphrase"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/portable-export |
  grep -q 'stdout=portable_backup=/tmp/obos-portable-exports/obos-portable-test.tar' \
  || fail "HTTP bridge did not run confirmed portable export mutation"

curl --fail --silent \
  'http://127.0.0.1:18091/obos/api/v1/downloads/portable-export?path=/tmp/obos-portable-exports/obos-portable-test.tar' |
  grep -q 'encrypted portable fixture' \
  || fail "HTTP bridge did not download encrypted portable export artifact"

curl --silent --output "${tmp_dir}/raw-backup-download.out" --write-out '%{http_code}' \
  'http://127.0.0.1:18091/obos/api/v1/downloads/portable-export?path=/srv/obos/backups/obos-openbridgeserver-test.tar.gz' |
  grep -q '^403$' \
  || fail "HTTP bridge did not reject raw backup download"
grep -q 'download-forbidden' "${tmp_dir}/raw-backup-download.out" \
  || fail "HTTP bridge raw backup download rejection missing marker"

curl --fail --silent \
  --header 'Content-Type: application/octet-stream' \
  --header 'X-Obos-Filename: obos-portable-upload-test.tar' \
  --data-binary 'encrypted portable upload fixture' \
  http://127.0.0.1:18091/obos/api/v1/uploads/portable-import |
  grep -q 'portable_backup=/tmp/obos-portable-imports/obos-portable-upload-' \
  || fail "HTTP bridge did not accept portable import upload"

cp "${portable_import_dir}"/obos-portable-upload-*.tar "${portable_import_dir}/obos-portable-upload-test.tar"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"portable-import-stage","portable_backup":"/tmp/obos-portable-imports/obos-portable-upload-test.tar","passphrase":"test-passphrase"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/portable-import-stage |
  grep -q 'stdout=format=obos-portable-import-stage-v1' \
  || fail "HTTP bridge did not run confirmed portable import staging"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"restart"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/restart |
  grep -q 'stdout=restart:ok' \
  || fail "HTTP bridge did not run confirmed restart mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"update"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/update |
  grep -q 'stdout=update:ok' \
  || fail "HTTP bridge did not run confirmed update mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"restore-stage","backup_path":"/srv/obos/backups/obos-openbridgeserver-test.tar.gz"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/restore-stage |
  grep -q 'stdout=format=obos-restore-stage-v1' \
  || fail "HTTP bridge did not run confirmed restore-stage mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"mqtt-enable-lan"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/mqtt-enable-lan |
  grep -q 'stdout=source_cidr=any' \
  || fail "HTTP bridge did not run confirmed MQTT enable mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"mqtt-enable-lan","source_cidr":"192.168.1.0/24"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/mqtt-enable-lan |
  grep -q 'stdout=source_cidr=192.168.1.0/24' \
  || fail "HTTP bridge did not forward MQTT source CIDR"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"mqtt-disable-lan"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/mqtt-disable-lan |
  grep -q 'stdout=lan_enabled=false' \
  || fail "HTTP bridge did not run confirmed MQTT disable mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"tls-generate"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/tls-generate |
  grep -q 'stdout=tls-generate:ok' \
  || fail "HTTP bridge did not run confirmed TLS generate mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"tls-export"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/tls-export |
  grep -q 'stdout=tls-export:ok' \
  || fail "HTTP bridge did not run confirmed TLS export mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"set-hostname","hostname":"obos-test"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/set-hostname |
  grep -q 'stdout=hostname=obos-test' \
  || fail "HTTP bridge did not run confirmed hostname mutation"

curl --fail --silent \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"set-timezone","timezone":"Europe/Zurich"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/set-timezone |
  grep -q 'stdout=timezone=Europe/Zurich' \
  || fail "HTTP bridge did not run confirmed timezone mutation"

curl --silent --output "${tmp_dir}/hostname-extra-field.out" --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"set-hostname","hostname":"obos-test","timezone":"Europe/Zurich"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/set-hostname |
  grep -q '^400$' \
  || fail "HTTP bridge did not reject unexpected hostname mutation body fields"
grep -q 'invalid-body' "${tmp_dir}/hostname-extra-field.out" \
  || fail "HTTP bridge hostname unexpected body rejection missing marker"

curl --silent --output "${tmp_dir}/mqtt-extra-field.out" --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"mqtt-disable-lan","source_cidr":"192.168.1.0/24"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/mqtt-disable-lan |
  grep -q '^400$' \
  || fail "HTTP bridge did not reject unexpected MQTT disable body fields"
grep -q 'invalid-body' "${tmp_dir}/mqtt-extra-field.out" \
  || fail "HTTP bridge MQTT unexpected body rejection missing marker"

curl --silent --output "${tmp_dir}/restore-stage-extra-field.out" --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"restore-stage","backup_path":"/srv/obos/backups/obos-openbridgeserver-test.tar.gz","extra":true}' \
  http://127.0.0.1:18091/obos/api/v1/actions/restore-stage |
  grep -q '^400$' \
  || fail "HTTP bridge did not reject unexpected restore-stage mutation body fields"
grep -q 'invalid-body' "${tmp_dir}/restore-stage-extra-field.out" \
  || fail "HTTP bridge restore-stage unexpected body rejection missing marker"

curl --silent --output "${tmp_dir}/backup-bad-confirm.out" --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"wrong"}' \
  http://127.0.0.1:18091/obos/api/v1/actions/backup |
  grep -q '^403$' \
  || fail "HTTP bridge did not reject wrong backup confirmation"
grep -q 'confirmation-mismatch' "${tmp_dir}/backup-bad-confirm.out" \
  || fail "HTTP bridge wrong confirmation rejection missing marker"

curl --silent --output "${tmp_dir}/backup-extra-field.out" --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"confirm":"backup","extra":true}' \
  http://127.0.0.1:18091/obos/api/v1/actions/backup |
  grep -q '^400$' \
  || fail "HTTP bridge did not reject unexpected mutation body fields"
grep -q 'invalid-body' "${tmp_dir}/backup-extra-field.out" \
  || fail "HTTP bridge unexpected body rejection missing marker"

curl --silent --output "${tmp_dir}/unknown.out" --write-out '%{http_code}' \
  http://127.0.0.1:18091/obos/api/v1/actions/unknown |
  grep -q '^404$' \
  || fail "HTTP bridge did not reject unknown action with 404"
grep -q 'format=obos-agent-http-error-v1' "${tmp_dir}/unknown.out" \
  || fail "HTTP bridge unknown action did not use error envelope"

curl --silent --output "${tmp_dir}/post.out" --write-out '%{http_code}' \
  -X POST http://127.0.0.1:18091/obos/api/v1/actions/status-summary |
  grep -q '^405$' \
  || fail "HTTP bridge did not reject POST with 405"
grep -q 'mutations-disabled' "${tmp_dir}/post.out" \
  || fail "HTTP bridge POST rejection missing mutation marker"

echo "obos-agent-http: PASS"
