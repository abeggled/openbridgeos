#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TLS_DIR="${TMP_DIR}/tls"
AUTO_RENEW="scripts/tls/auto-renew-leaf-certificate.sh"
CALLS="${TMP_DIR}/calls"

fail() {
  echo "TLS automatic renewal fixture failed: $1" >&2
  exit 1
}

mkdir -p "${TLS_DIR}"
openssl req -x509 -nodes -newkey rsa:2048 \
  -subj "//CN=fixture CA" \
  -keyout "${TLS_DIR}/ca.key" \
  -out "${TLS_DIR}/ca.crt" \
  -days 3650 >/dev/null 2>&1

issue_leaf() {
  days="$1"
  openssl req -new -nodes -newkey rsa:2048 \
    -subj "//CN=obs.local" \
    -keyout "${TLS_DIR}/leaf.key" \
    -out "${TLS_DIR}/leaf.csr" >/dev/null 2>&1
  openssl x509 -req \
    -in "${TLS_DIR}/leaf.csr" \
    -CA "${TLS_DIR}/ca.crt" \
    -CAkey "${TLS_DIR}/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/leaf.crt" \
    -days "${days}" \
    -sha256 >/dev/null 2>&1
}

cat > "${TMP_DIR}/obosctl" <<EOF
#!/usr/bin/env sh
printf '%s\n' "\$*" >> "${CALLS}"
EOF
chmod 0755 "${TMP_DIR}/obosctl"

issue_leaf 90
OBOS_ALLOW_NON_ROOT_TLS_AUTO_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TLS_LEAF_CERT="${TLS_DIR}/leaf.crt" \
  OBOS_TLS_OBOSCTL="${TMP_DIR}/obosctl" \
  sh "${AUTO_RENEW}" |
  grep -q '^renewal_due=false$' \
  || fail "fresh 90-day leaf was not left unchanged"
[ ! -e "${CALLS}" ] || fail "fresh leaf triggered a renewal"

issue_leaf 120
OBOS_ALLOW_NON_ROOT_TLS_AUTO_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TLS_LEAF_CERT="${TLS_DIR}/leaf.crt" \
  OBOS_TLS_OBOSCTL="${TMP_DIR}/obosctl" \
  sh "${AUTO_RENEW}" |
  grep -q '^renewal_reason=leaf_validity_exceeds_90_days$' \
  || fail "legacy overlong leaf did not trigger renewal"

issue_leaf 42
OBOS_ALLOW_NON_ROOT_TLS_AUTO_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TLS_LEAF_CERT="${TLS_DIR}/leaf.crt" \
  OBOS_TLS_OBOSCTL="${TMP_DIR}/obosctl" \
  sh "${AUTO_RENEW}" |
  grep -q '^renewal_reason=leaf_age_reached_47_days$' \
  || fail "leaf inside the 43-day remaining window did not renew"

[ "$(grep -c '^tls-renew-leaf --confirm tls-renew-leaf$' "${CALLS}")" -eq 2 ] \
  || fail "automatic renewal did not use the confirmed leaf-only command"

echo "TLS automatic renewal fixture: PASS"
