#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TLS_DIR="${TMP_DIR}/tls"
TRUST_DIR="${TMP_DIR}/trust"
EXPORT_SCRIPT="${TMP_DIR}/export-trust-bundle.sh"
CHECKER="scripts/tls/renew-leaf-certificate.sh"
FIXTURE_BIN="${TMP_DIR}/bin"

fail() {
  echo "tls leaf renewal fixture failed: $1" >&2
  exit 1
}

mkdir -p "${TLS_DIR}" "${TRUST_DIR}" "${FIXTURE_BIN}"
NETWORK_CONFIG_FILE="${TMP_DIR}/10-obos-managed.network"
cat > "${NETWORK_CONFIG_FILE}" <<'EOF'
[Match]
Name=ens18

[Network]
Address=10.38.114.114/24
Gateway=10.38.114.1
EOF
export OBOS_NETWORK_CONFIG_FILE="${NETWORK_CONFIG_FILE}"

cat > "${FIXTURE_BIN}/hostname" <<'EOF'
#!/usr/bin/env sh
case "${1:-}" in
  -f) echo "obos-unit.example.test" ;;
  -I) echo "10.38.114.132 172.17.0.1" ;;
  *) echo "obos-unit" ;;
esac
EOF
cat > "${FIXTURE_BIN}/ip" <<'EOF'
#!/usr/bin/env sh
case "$*" in
  "-o route show default") echo "default via 10.38.114.1 dev ens18" ;;
  "-o -6 route show default") : ;;
  "-o addr show dev ens18 scope global") printf '%s\n' "2: ens18 inet 10.38.114.114/24 brd 10.38.114.255 scope global ens18" "2: ens18 inet 10.38.114.101/24 brd 10.38.114.255 scope global secondary ens18" ;;
  *) exit 1 ;;
esac
EOF
chmod 0755 "${FIXTURE_BIN}/hostname" "${FIXTURE_BIN}/ip"

openssl genrsa -out "${TLS_DIR}/obos-local-ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -nodes \
  -key "${TLS_DIR}/obos-local-ca.key" \
  -sha256 \
  -days 3650 \
  -subj "//CN=open bridge operating system local CA fixture" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out "${TLS_DIR}/obos-local-ca.crt" >/dev/null 2>&1

openssl genrsa -out "${TLS_DIR}/obos.local.key" 2048 >/dev/null 2>&1
openssl req -new \
  -key "${TLS_DIR}/obos.local.key" \
  -subj "//CN=obs.local" \
  -out "${TLS_DIR}/obos.local.csr" >/dev/null 2>&1
cat > "${TLS_DIR}/obos.local.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:obs.local
EOF
openssl x509 -req \
  -in "${TLS_DIR}/obos.local.csr" \
  -CA "${TLS_DIR}/obos-local-ca.crt" \
  -CAkey "${TLS_DIR}/obos-local-ca.key" \
  -CAcreateserial \
  -out "${TLS_DIR}/obos.local.crt" \
  -days 30 \
  -sha256 \
  -extfile "${TLS_DIR}/obos.local.ext" >/dev/null 2>&1

cat > "${EXPORT_SCRIPT}" <<'EOF'
#!/usr/bin/env sh
set -eu

install -m 0644 "${OBOS_TLS_DIR}/obos-local-ca.crt" "${OBOS_TRUST_EXPORT_DIR}/obos-local-ca.crt"
install -m 0644 "${OBOS_TLS_DIR}/obos.local.crt" "${OBOS_TRUST_EXPORT_DIR}/obos.local.crt"
printf 'fixture trust info\n' > "${OBOS_TRUST_EXPORT_DIR}/trust-info.txt"
EOF
chmod 0755 "${EXPORT_SCRIPT}"

old_ca_fingerprint="$(openssl x509 -in "${TLS_DIR}/obos-local-ca.crt" -noout -fingerprint -sha256)"
old_leaf_fingerprint="$(openssl x509 -in "${TLS_DIR}/obos.local.crt" -noout -fingerprint -sha256)"

OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TRUST_EXPORT_DIR="${TRUST_DIR}" \
  OBOS_TLS_EXPORT_SCRIPT="${EXPORT_SCRIPT}" \
  OBOS_TLS_RELOAD_NGINX=0 \
  OBOS_TLS_LEAF_SUBJECT="//CN=obs.local" \
  PATH="${FIXTURE_BIN}:${PATH}" \
  sh "${CHECKER}" --confirm tls-renew-leaf |
  grep -q '^result=PASS$' \
  || fail "valid leaf renewal did not pass"

openssl x509 -in "${TLS_DIR}/obos.local.crt" -noout -checkend $((89 * 24 * 60 * 60)) >/dev/null 2>&1 \
  || fail "renewed leaf is not valid for the expected 90-day policy"

new_ca_fingerprint="$(openssl x509 -in "${TLS_DIR}/obos-local-ca.crt" -noout -fingerprint -sha256)"
new_leaf_fingerprint="$(openssl x509 -in "${TLS_DIR}/obos.local.crt" -noout -fingerprint -sha256)"

[ "${old_ca_fingerprint}" = "${new_ca_fingerprint}" ] \
  || fail "local CA changed during leaf renewal"
[ "${old_leaf_fingerprint}" != "${new_leaf_fingerprint}" ] \
  || fail "leaf certificate did not change during renewal"
[ -f "${TRUST_DIR}/obos-local-ca.crt" ] \
  || fail "trust export did not include local CA"
[ -f "${TRUST_DIR}/obos.local.crt" ] \
  || fail "trust export did not include leaf certificate"
find "${TLS_DIR}/backups" -type f -name obos.local.key | grep -q . \
  || fail "pre-change leaf key backup was not created"
grep -q '^DNS.1=obos-unit.example.test$' "${TLS_DIR}/obos.local.ext" \
  || fail "current FQDN is not the first leaf DNS SAN"
if grep -q 'obs.local' "${TLS_DIR}/obos.local.ext"; then
  fail "legacy obs.local alias remained in renewed leaf SANs"
fi
grep -q '^IP.1=10.38.114.114$' "${TLS_DIR}/obos.local.ext" \
  || fail "managed static host address is missing from leaf SANs"
if grep -q '10.38.114.101' "${TLS_DIR}/obos.local.ext"; then
  fail "stale DHCP address remained in renewed leaf SANs"
fi
if grep -Eq '172\.17\.|172\.18\.|172\.19\.' "${TLS_DIR}/obos.local.ext"; then
  fail "container bridge address leaked into renewed leaf SANs"
fi

renewal_count=0
while [ "${renewal_count}" -lt 2 ]; do
  OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 \
    OBOS_TLS_DIR="${TLS_DIR}" \
    OBOS_TRUST_EXPORT_DIR="${TRUST_DIR}" \
    OBOS_TLS_EXPORT_SCRIPT="${EXPORT_SCRIPT}" \
    OBOS_TLS_RELOAD_NGINX=0 \
    OBOS_TLS_LEAF_SUBJECT="//CN=obs.local" \
    PATH="${FIXTURE_BIN}:${PATH}" \
    sh "${CHECKER}" --confirm tls-renew-leaf >/dev/null
  renewal_count=$((renewal_count + 1))
done
[ "$(find "${TLS_DIR}/backups" -mindepth 1 -maxdepth 1 -type d -name 'leaf-*' | wc -l)" -eq 1 ] \
  || fail "leaf backup retention did not prune older recovery copies"

if OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 OBOS_TLS_DIR="${TLS_DIR}" sh "${CHECKER}" >/dev/null 2>&1; then
  fail "leaf renewal accepted missing confirmation"
fi

mv "${TLS_DIR}/obos-local-ca.key" "${TLS_DIR}/obos-local-ca.key.missing"
if OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TLS_RELOAD_NGINX=0 \
  OBOS_TLS_LEAF_SUBJECT="//CN=obs.local" \
  sh "${CHECKER}" --confirm tls-renew-leaf >/dev/null 2>&1; then
  fail "leaf renewal accepted missing local CA key"
fi

echo "tls leaf renewal fixture: PASS"
