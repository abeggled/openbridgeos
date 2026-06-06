#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TLS_DIR="${TMP_DIR}/tls"
TRUST_DIR="${TMP_DIR}/trust"
EXPORT_SCRIPT="${TMP_DIR}/export-trust-bundle.sh"
CHECKER="scripts/tls/renew-leaf-certificate.sh"

fail() {
  echo "tls leaf renewal fixture failed: $1" >&2
  exit 1
}

mkdir -p "${TLS_DIR}" "${TRUST_DIR}"

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
  -subj "//CN=obos.local" \
  -out "${TLS_DIR}/obos.local.csr" >/dev/null 2>&1
cat > "${TLS_DIR}/obos.local.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:obos.local
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
  OBOS_TLS_LEAF_SUBJECT="//CN=obos.local" \
  sh "${CHECKER}" --confirm tls-renew-leaf |
  grep -q '^result=PASS$' \
  || fail "valid leaf renewal did not pass"

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

if OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 OBOS_TLS_DIR="${TLS_DIR}" sh "${CHECKER}" >/dev/null 2>&1; then
  fail "leaf renewal accepted missing confirmation"
fi

mv "${TLS_DIR}/obos-local-ca.key" "${TLS_DIR}/obos-local-ca.key.missing"
if OBOS_ALLOW_NON_ROOT_TLS_RENEWAL=1 \
  OBOS_TLS_DIR="${TLS_DIR}" \
  OBOS_TLS_RELOAD_NGINX=0 \
  OBOS_TLS_LEAF_SUBJECT="//CN=obos.local" \
  sh "${CHECKER}" --confirm tls-renew-leaf >/dev/null 2>&1; then
  fail "leaf renewal accepted missing local CA key"
fi

echo "tls leaf renewal fixture: PASS"
