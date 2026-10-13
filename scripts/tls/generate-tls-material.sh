#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
CA_KEY="${TLS_DIR}/obos-local-ca.key"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_KEY="${TLS_DIR}/obos.local.key"
LEAF_CERT="${TLS_DIR}/obos.local.crt"
LEAF_CSR="${TLS_DIR}/obos.local.csr"
LEAF_EXT="${TLS_DIR}/obos.local.ext"
IP_LIST="${TLS_DIR}/obos.local.ips"
DNS_LIST="${TLS_DIR}/obos.local.dns"
DAYS_CA="${OBOS_TLS_CA_DAYS:-3650}"
DAYS_LEAF="${OBOS_TLS_LEAF_DAYS:-90}"

if [ "$(id -u)" -ne 0 ]; then
  echo "generate-tls-material.sh must run as root" >&2
  exit 1
fi

install -d -m 0700 "${TLS_DIR}"

ca_created=0
if [ ! -f "${CA_KEY}" ] || [ ! -f "${CA_CERT}" ]; then
  ca_created=1
  openssl genrsa -out "${CA_KEY}" 4096
  chmod 0600 "${CA_KEY}"
  openssl req -x509 -new -nodes \
    -key "${CA_KEY}" \
    -sha256 \
    -days "${DAYS_CA}" \
    -subj "/CN=open bridge operating system local CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash" \
    -out "${CA_CERT}"
  chmod 0644 "${CA_CERT}"
fi

if [ "${ca_created}" -eq 0 ] && [ -f "${LEAF_KEY}" ] && [ -f "${LEAF_CERT}" ]; then
  chmod 0600 "${LEAF_KEY}"
  chmod 0644 "${LEAF_CERT}"
  printf 'TLS material already exists in %s\n' "${TLS_DIR}"
  exit 0
fi

openssl genrsa -out "${LEAF_KEY}" 4096
chmod 0600 "${LEAF_KEY}"
: > "${IP_LIST}"
if command -v ip >/dev/null 2>&1; then
  {
    ip -o route show default 2>/dev/null || true
    ip -o -6 route show default 2>/dev/null || true
  } | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == "dev") {
          print $(i + 1)
          break
        }
      }
    }
  ' | awk 'NF && !seen[$0]++' |
    while IFS= read -r interface; do
      ip -o addr show dev "${interface}" scope global 2>/dev/null || true
    done |
    awk '{ value=$4; sub(/\/.*/, "", value); if (value != "" && !seen[value]++) print value }' > "${IP_LIST}"
else
  hostname -I 2>/dev/null | tr ' ' '\n' > "${IP_LIST}" || true
fi
{
  hostname -f 2>/dev/null || true
  hostname 2>/dev/null || true
} | awk 'NF && /^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$/ && !seen[$0]++' > "${DNS_LIST}"
leaf_common_name="$(sed -n '1p' "${DNS_LIST}")"
[ -n "${leaf_common_name}" ] || leaf_common_name=localhost
openssl req -new -key "${LEAF_KEY}" -subj "/CN=${leaf_common_name}" -out "${LEAF_CSR}"

{
  echo "authorityKeyIdentifier=keyid,issuer"
  echo "basicConstraints=critical,CA:FALSE"
  echo "keyUsage=critical,digitalSignature,keyEncipherment"
  echo "extendedKeyUsage=serverAuth"
  echo "subjectAltName=@alt_names"
  echo ""
  echo "[alt_names]"
  dns_index=1
  while IFS= read -r dns_name; do
    [ -n "${dns_name}" ] || continue
    echo "DNS.${dns_index}=${dns_name}"
    dns_index=$((dns_index + 1))
  done < "${DNS_LIST}"
  index=1
  while IFS= read -r ip; do
    [ -n "${ip}" ] || continue
    echo "IP.${index}=${ip}"
    index=$((index + 1))
  done < "${IP_LIST}"
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
rm -f "${LEAF_CSR}" "${IP_LIST}" "${DNS_LIST}"

printf 'TLS material written to %s\n' "${TLS_DIR}"
