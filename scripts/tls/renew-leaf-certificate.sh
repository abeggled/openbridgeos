#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
CA_KEY="${TLS_DIR}/obos-local-ca.key"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_KEY="${TLS_DIR}/obos.local.key"
LEAF_CERT="${TLS_DIR}/obos.local.crt"
LEAF_EXT="${TLS_DIR}/obos.local.ext"
DAYS_LEAF="${OBOS_TLS_LEAF_DAYS:-397}"
EXPORT_SCRIPT="${OBOS_TLS_EXPORT_SCRIPT:-/usr/lib/obos/export-trust-bundle.sh}"
RELOAD_NGINX="${OBOS_TLS_RELOAD_NGINX:-1}"
ALLOW_NON_ROOT="${OBOS_ALLOW_NON_ROOT_TLS_RENEWAL:-0}"
SUBJECT="${OBOS_TLS_LEAF_SUBJECT:-/CN=obs.local}"

fail() {
  echo "tls leaf renewal failed: $1" >&2
  exit 1
}

cert_fingerprint() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -fingerprint -sha256 |
    sed 's/^sha256 Fingerprint=//; s/^SHA256 Fingerprint=//'
}

require_cert() {
  cert="$1"
  label="$2"
  [ -f "${cert}" ] || fail "${label} certificate missing: ${cert}"
  openssl x509 -in "${cert}" -noout >/dev/null 2>&1 \
    || fail "${label} certificate is not parseable: ${cert}"
}

require_key() {
  key="$1"
  label="$2"
  [ -f "${key}" ] || fail "${label} key missing: ${key}"
  [ -s "${key}" ] || fail "${label} key is empty: ${key}"
}

if [ "$(id -u)" -ne 0 ] && [ "${ALLOW_NON_ROOT}" != "1" ]; then
  fail "renew-leaf-certificate.sh must run as root"
fi

if [ "${1:-}" != "--confirm" ] || [ "${2:-}" != "tls-renew-leaf" ]; then
  fail "explicit confirmation required: --confirm tls-renew-leaf"
fi
case "${DAYS_LEAF}" in
  ''|*[!0-9]*) fail "OBOS_TLS_LEAF_DAYS must be a positive integer" ;;
  0) fail "OBOS_TLS_LEAF_DAYS must be greater than zero" ;;
esac

command -v openssl >/dev/null 2>&1 || fail "openssl is required"
require_cert "${CA_CERT}" local_ca
require_key "${CA_KEY}" local_ca
require_cert "${LEAF_CERT}" leaf
require_key "${LEAF_KEY}" leaf

old_ca_fingerprint="$(cert_fingerprint "${CA_CERT}")"
old_leaf_fingerprint="$(cert_fingerprint "${LEAF_CERT}")"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${TLS_DIR}/backups"
work_dir="$(mktemp -d "${TLS_DIR}/leaf-renew.XXXXXXXX")"
new_key="${work_dir}/obos.local.key"
new_csr="${work_dir}/obos.local.csr"
new_cert="${work_dir}/obos.local.crt"
new_ext="${work_dir}/obos.local.ext"
ip_list="${work_dir}/obos.local.ips"

cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT INT TERM

if [ "${ALLOW_NON_ROOT}" = "1" ]; then
  mkdir -p "${backup_root}"
  backup_dir="$(mktemp -d "${backup_root}/leaf-${stamp}.XXXXXXXX")"
  cp "${LEAF_KEY}" "${backup_dir}/obos.local.key"
  cp "${LEAF_CERT}" "${backup_dir}/obos.local.crt"
  if [ -f "${LEAF_EXT}" ]; then
    cp "${LEAF_EXT}" "${backup_dir}/obos.local.ext"
  fi
else
  install -d -m 0700 "${backup_root}"
  backup_dir="$(mktemp -d "${backup_root}/leaf-${stamp}.XXXXXXXX")"
  chmod 0700 "${backup_dir}"
  install -m 0600 "${LEAF_KEY}" "${backup_dir}/obos.local.key"
  install -m 0644 "${LEAF_CERT}" "${backup_dir}/obos.local.crt"
  if [ -f "${LEAF_EXT}" ]; then
    install -m 0644 "${LEAF_EXT}" "${backup_dir}/obos.local.ext"
  fi
fi

openssl genrsa -out "${new_key}" 4096 >/dev/null 2>&1
chmod 0600 "${new_key}"
openssl req -new -key "${new_key}" -subj "${SUBJECT}" -out "${new_csr}" >/dev/null 2>&1
: > "${ip_list}"
hostname -I 2>/dev/null | tr ' ' '\n' > "${ip_list}" || true

{
  echo "authorityKeyIdentifier=keyid,issuer"
  echo "basicConstraints=critical,CA:FALSE"
  echo "keyUsage=critical,digitalSignature,keyEncipherment"
  echo "extendedKeyUsage=serverAuth"
  echo "subjectAltName=@alt_names"
  echo ""
  echo "[alt_names]"
  echo "DNS.1=obs.local"
  index=1
  while IFS= read -r ip; do
    [ -n "${ip}" ] || continue
    echo "IP.${index}=${ip}"
    index=$((index + 1))
  done < "${ip_list}"
} > "${new_ext}"

openssl x509 -req \
  -in "${new_csr}" \
  -CA "${CA_CERT}" \
  -CAkey "${CA_KEY}" \
  -CAcreateserial \
  -out "${new_cert}" \
  -days "${DAYS_LEAF}" \
  -sha256 \
  -extfile "${new_ext}" >/dev/null 2>&1

openssl verify -CAfile "${CA_CERT}" "${new_cert}" >/dev/null 2>&1 \
  || fail "new leaf certificate does not verify against the local CA"

if [ "${ALLOW_NON_ROOT}" = "1" ]; then
  cp "${new_key}" "${LEAF_KEY}"
  cp "${new_cert}" "${LEAF_CERT}"
  cp "${new_ext}" "${LEAF_EXT}"
else
  install -m 0600 "${new_key}" "${LEAF_KEY}"
  install -m 0644 "${new_cert}" "${LEAF_CERT}"
  install -m 0644 "${new_ext}" "${LEAF_EXT}"
fi

new_ca_fingerprint="$(cert_fingerprint "${CA_CERT}")"
[ "${new_ca_fingerprint}" = "${old_ca_fingerprint}" ] \
  || fail "local CA fingerprint changed unexpectedly"
new_leaf_fingerprint="$(cert_fingerprint "${LEAF_CERT}")"

trust_export_refreshed=false
if [ -x "${EXPORT_SCRIPT}" ]; then
  "${EXPORT_SCRIPT}" >/dev/null
  trust_export_refreshed=true
fi

nginx_reloaded=skipped
if [ "${RELOAD_NGINX}" = "1" ] && command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active nginx.service >/dev/null 2>&1; then
    systemctl reload nginx.service
    nginx_reloaded=true
  else
    nginx_reloaded=inactive
  fi
fi

echo "format=obos-tls-leaf-renewal-v1"
echo "tls_dir=${TLS_DIR}"
echo "backup_dir=${backup_dir}"
echo "preserves_local_ca=true"
echo "client_reonboarding_required=false"
echo "old_local_ca_sha256_fingerprint=${old_ca_fingerprint}"
echo "new_local_ca_sha256_fingerprint=${new_ca_fingerprint}"
echo "old_leaf_sha256_fingerprint=${old_leaf_fingerprint}"
echo "new_leaf_sha256_fingerprint=${new_leaf_fingerprint}"
echo "trust_export_refreshed=${trust_export_refreshed}"
echo "nginx_reloaded=${nginx_reloaded}"
echo "result=PASS"
