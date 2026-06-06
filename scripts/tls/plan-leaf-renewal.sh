#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
CA_KEY="${TLS_DIR}/obos-local-ca.key"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_KEY="${TLS_DIR}/obos.local.key"
LEAF_CERT="${TLS_DIR}/obos.local.crt"
EXPORT_DIR="${OBOS_TRUST_EXPORT_DIR:-/srv/obos/state/trust}"
WARN_DAYS="${OBOS_TLS_EXPIRY_WARN_DAYS:-30}"

fail() {
  echo "tls leaf renewal plan failed: $1" >&2
  exit 1
}

cert_fingerprint() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -fingerprint -sha256 |
    sed 's/^sha256 Fingerprint=//; s/^SHA256 Fingerprint=//'
}

cert_not_after() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -enddate | sed 's/^notAfter=//'
}

require_cert() {
  cert="$1"
  label="$2"
  [ -f "${cert}" ] || fail "${label} certificate missing: ${cert}"
  openssl x509 -in "${cert}" -noout >/dev/null 2>&1 \
    || fail "${label} certificate is not parseable: ${cert}"
}

case "${WARN_DAYS}" in
  ''|*[!0-9]*) fail "OBOS_TLS_EXPIRY_WARN_DAYS must be a non-negative integer" ;;
esac

command -v openssl >/dev/null 2>&1 || fail "openssl is required"
require_cert "${CA_CERT}" local_ca
require_cert "${LEAF_CERT}" leaf
[ -f "${CA_KEY}" ] || fail "local CA key missing: ${CA_KEY}"
[ -f "${LEAF_KEY}" ] || fail "leaf key missing: ${LEAF_KEY}"

warn_seconds=$((WARN_DAYS * 24 * 60 * 60))
renewal_reason=operator_requested
renewal_due=false
if ! openssl x509 -in "${LEAF_CERT}" -noout -checkend "${warn_seconds}" >/dev/null 2>&1; then
  renewal_reason=leaf_expires_within_${WARN_DAYS}_days
  renewal_due=true
fi

cat <<EOF
format=obos-tls-leaf-renewal-plan-v1
mode=non-destructive
tls_dir=${TLS_DIR}
trust_export_dir=${EXPORT_DIR}
local_ca_cert=${CA_CERT}
leaf_cert=${LEAF_CERT}
local_ca_sha256_fingerprint=$(cert_fingerprint "${CA_CERT}")
leaf_sha256_fingerprint=$(cert_fingerprint "${LEAF_CERT}")
leaf_not_after=$(cert_not_after "${LEAF_CERT}")
warn_days=${WARN_DAYS}
renewal_due=${renewal_due}
renewal_reason=${renewal_reason}
preserves_local_ca=true
client_reonboarding_required=false
private_keys_exported=false
prechange_backup_required=true
trust_export_refresh_required=true
post_tls_summary_required=true
post_proxy_health_required=true
live_change_allowed=false
confirmed_command=sudo obosctl tls-renew-leaf --confirm tls-renew-leaf
next=run_confirmed_command_from_local_cli_after_reviewing_this_plan
result=PASS
EOF
