#!/usr/bin/env sh
set -eu

BRIDGE="scripts/agent/obos-agent-http.py"
SERVICE="packaging/systemd/obos-agent-http.service"
NGINX_CONF="packaging/nginx/openbridgeserver.conf"

fail() {
  echo "obos-agent-http check failed: $1" >&2
  exit 1
}

[ -f "${BRIDGE}" ] || fail "HTTP bridge script missing"
[ -f "${SERVICE}" ] || fail "HTTP bridge systemd unit missing"

python3 -m py_compile "${BRIDGE}" \
  || fail "HTTP bridge Python syntax failed"

grep -q 'READ_ONLY_ACTIONS' "${BRIDGE}" \
  || fail "read-only action allowlist missing"
grep -q 'MUTATING_ACTIONS' "${BRIDGE}" \
  || fail "mutating action allowlist missing"
grep -q '"backup": "backup"' "${BRIDGE}" \
  || fail "backup mutation is not exposed with a matching confirmation token"
grep -q '"start": "start"' "${BRIDGE}" \
  || fail "start mutation is not exposed with a matching confirmation token"
grep -q '"stop": "stop"' "${BRIDGE}" \
  || fail "stop mutation is not exposed with a matching confirmation token"
grep -q '"restart": "restart"' "${BRIDGE}" \
  || fail "restart mutation is not exposed with a matching confirmation token"
grep -q '"restore-stage": "restore-stage"' "${BRIDGE}" \
  || fail "restore-stage mutation is not exposed with a matching confirmation token"
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
trap 'if [ -n "${server_pid:-}" ]; then kill "${server_pid}" 2>/dev/null || true; fi; rm -rf "${tmp_dir}"' EXIT

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
  *)
    echo "unexpected action: ${1:-missing}" >&2
    exit 2
    ;;
esac
EOF
chmod 0755 "${tmp_dir}/obos-agent"

OBOS_AGENT_PATH="${tmp_dir}/obos-agent" \
OBOS_AGENT_HTTP_BIND=127.0.0.1 \
OBOS_AGENT_HTTP_PORT=18091 \
python3 "${BRIDGE}" &
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
