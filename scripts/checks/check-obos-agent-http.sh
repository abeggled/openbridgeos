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
grep -q '"backup-list"' "${BRIDGE}" \
  || fail "backup-list is not exposed by the read-only HTTP bridge"
grep -q '"update-rollback-plan"' "${BRIDGE}" \
  || fail "update-rollback-plan is not exposed by the read-only HTTP bridge"
grep -q 'OBOS_AGENT_PATH' "${BRIDGE}" \
  || fail "agent path is not configurable"
grep -q '127.0.0.1' "${BRIDGE}" \
  || fail "bridge does not enforce loopback binding"
grep -q 'subprocess.run' "${BRIDGE}" \
  || fail "bridge does not call obos-agent as a subprocess"
grep -q '\[AGENT_PATH, action\]' "${BRIDGE}" \
  || fail "bridge does not avoid shell command construction"
grep -q 'do_POST' "${BRIDGE}" \
  || fail "bridge does not explicitly handle POST"
grep -q 'mutations-disabled' "${BRIDGE}" \
  || fail "bridge does not reject HTTP mutations"
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

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/backup-list |
  grep -q 'stdout=backup_count=2' \
  || fail "HTTP bridge did not expose backup inventory"

curl --fail --silent http://127.0.0.1:18091/obos/api/v1/actions/update-rollback-plan |
  grep -q 'stdout=backup_present=true' \
  || fail "HTTP bridge did not expose update rollback plan"

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
