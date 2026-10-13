#!/usr/bin/env sh
set -eu

OBOSCTL="scripts/obosctl"

fail() {
  echo "OBS version fixture failed: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
mock_bin="${tmp_dir}/bin"
mkdir -p "${mock_bin}"
touch "${tmp_dir}/ca.crt"

cat > "${mock_bin}/systemctl" <<'EOF'
#!/usr/bin/env sh
if [ "${1:-}" = is-active ]; then
  echo active
  exit 0
fi
exit 1
EOF

cat > "${mock_bin}/curl" <<'EOF'
#!/usr/bin/env sh
printf '%s' "${OBOS_TEST_HEALTH_RESPONSE:-}"
EOF

chmod 0755 "${mock_bin}/systemctl" "${mock_bin}/curl"

summary="$({
  PATH="${mock_bin}:${PATH}" \
  OBOS_HEALTH_URL="http://127.0.0.1:8080/api/v1/system/health" \
  OBOS_PROXY_HEALTH_URL="https://obos.test/api/v1/system/health" \
  OBOS_PROXY_HEALTH_HOST="obos.test" \
  OBOS_TLS_CA_CERT="${tmp_dir}/ca.crt" \
  OBOS_TEST_HEALTH_RESPONSE='{"status":"ok","version":"2026.10.0"}' \
    sh "${OBOSCTL}" status-summary
})"

printf '%s\n' "${summary}" | grep -q '^obs_version=2026.10.0$' \
  || fail "valid health version was not reported"

summary="$({
  PATH="${mock_bin}:${PATH}" \
  OBOS_HEALTH_URL="http://127.0.0.1:8080/api/v1/system/health" \
  OBOS_PROXY_HEALTH_URL="https://obos.test/api/v1/system/health" \
  OBOS_PROXY_HEALTH_HOST="obos.test" \
  OBOS_TLS_CA_CERT="${tmp_dir}/ca.crt" \
  OBOS_TEST_HEALTH_RESPONSE='{"status":"ok","version":"<script>"}' \
    sh "${OBOSCTL}" status-summary
})"

printf '%s\n' "${summary}" | grep -q '^obs_version=unknown$' \
  || fail "unsafe health version was not rejected"

echo "OBS version fixture: PASS"
