#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TLS_DIR="${TMP_DIR}/tls"
CHECKER="scripts/tls/plan-leaf-renewal.sh"

fail() {
  echo "tls leaf renewal plan fixture failed: $1" >&2
  exit 1
}

mkdir -p "${TLS_DIR}"

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
  -days 397 \
  -sha256 \
  -extfile "${TLS_DIR}/obos.local.ext" >/dev/null 2>&1

OBOS_TLS_DIR="${TLS_DIR}" OBOS_TLS_EXPIRY_WARN_DAYS=30 sh "${CHECKER}" |
  grep -q '^result=PASS$' \
  || fail "valid leaf renewal plan did not pass"

OBOS_TLS_DIR="${TLS_DIR}" OBOS_TLS_EXPIRY_WARN_DAYS=500 sh "${CHECKER}" |
  grep -q '^renewal_due=true$' \
  || fail "near-expiry leaf renewal was not reported"

mv "${TLS_DIR}/obos-local-ca.key" "${TLS_DIR}/obos-local-ca.key.missing"
if OBOS_TLS_DIR="${TLS_DIR}" sh "${CHECKER}" >/dev/null 2>&1; then
  fail "plan accepted missing local CA key"
fi
mv "${TLS_DIR}/obos-local-ca.key.missing" "${TLS_DIR}/obos-local-ca.key"

mv "${TLS_DIR}/obos.local.crt" "${TLS_DIR}/obos.local.crt.missing"
if OBOS_TLS_DIR="${TLS_DIR}" sh "${CHECKER}" >/dev/null 2>&1; then
  fail "plan accepted missing leaf certificate"
fi

echo "tls leaf renewal plan fixture: PASS"
