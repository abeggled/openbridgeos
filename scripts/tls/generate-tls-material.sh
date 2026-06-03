#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
HOSTNAME_VALUE="${OBOS_HOSTNAME:-$(hostname)}"
CA_KEY="${TLS_DIR}/obos-local-ca.key"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_KEY="${TLS_DIR}/obos.local.key"
LEAF_CERT="${TLS_DIR}/obos.local.crt"
LEAF_CSR="${TLS_DIR}/obos.local.csr"
LEAF_EXT="${TLS_DIR}/obos.local.ext"
DAYS_CA="${OBOS_TLS_CA_DAYS:-3650}"
DAYS_LEAF="${OBOS_TLS_LEAF_DAYS:-397}"

if [ "$(id -u)" -ne 0 ]; then
  echo "generate-tls-material.sh must run as root" >&2
  exit 1
fi

install -d -m 0700 "${TLS_DIR}"

if [ ! -f "${CA_KEY}" ] || [ ! -f "${CA_CERT}" ]; then
  openssl genrsa -out "${CA_KEY}" 4096
  chmod 0600 "${CA_KEY}"
  openssl req -x509 -new -nodes \
    -key "${CA_KEY}" \
    -sha256 \
    -days "${DAYS_CA}" \
    -subj "/CN=Open Bridge OS Local CA ${HOSTNAME_VALUE}" \
    -out "${CA_CERT}"
  chmod 0644 "${CA_CERT}"
fi

openssl genrsa -out "${LEAF_KEY}" 4096
chmod 0600 "${LEAF_KEY}"
openssl req -new -key "${LEAF_KEY}" -subj "/CN=${HOSTNAME_VALUE}" -out "${LEAF_CSR}"

{
  echo "authorityKeyIdentifier=keyid,issuer"
  echo "basicConstraints=CA:FALSE"
  echo "keyUsage=digitalSignature,keyEncipherment"
  echo "extendedKeyUsage=serverAuth"
  echo "subjectAltName=@alt_names"
  echo ""
  echo "[alt_names]"
  echo "DNS.1=obos.local"
  echo "DNS.2=${HOSTNAME_VALUE}"
  echo "DNS.3=${HOSTNAME_VALUE}.local"
  index=1
  hostname -I 2>/dev/null | tr ' ' '\n' | while IFS= read -r ip; do
    [ -n "${ip}" ] || continue
    echo "IP.${index}=${ip}"
    index=$((index + 1))
  done
} > "${LEAF_EXT}"

openssl x509 -req \
  -in "${LEAF_CSR}" \
  -CA "${CA_CERT}" \
  -CAkey "${CA_KEY}" \
  -CAcreateserial \
  -out "${LEAF_CERT}" \
  -days "${DAYS_LEAF}" \
  -sha256 \
  -extfile "${LEAF_EXT}"

chmod 0644 "${LEAF_CERT}"
rm -f "${LEAF_CSR}"

printf 'TLS material written to %s\n' "${TLS_DIR}"
