#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
EXPORT_DIR="${OBOS_TRUST_EXPORT_DIR:-/srv/obos/state/trust}"
CA_CERT="${OBOS_TLS_CA_CERT:-${TLS_DIR}/obos-local-ca.crt}"
LEAF_CERT="${OBOS_TLS_LEAF_CERT:-${TLS_DIR}/obos.local.crt}"
WARN_DAYS="${OBOS_TLS_EXPIRY_WARN_DAYS:-30}"

fail() {
  echo "FAIL $1" >&2
  exit 1
}

warn() {
  echo "WARN $1"
}

cert_fingerprint() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -fingerprint -sha256 |
    sed 's/^sha256 Fingerprint=//; s/^SHA256 Fingerprint=//'
}

cert_subject() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -subject | sed 's/^subject=//'
}

cert_issuer() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -issuer | sed 's/^issuer=//'
}

cert_not_after() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -enddate | sed 's/^notAfter=//'
}

cert_summary() {
  cert="$1"
  label="$2"

  if [ ! -f "${cert}" ]; then
    echo "${label}_present=false"
    echo "${label}_path=${cert}"
    echo "${label}_expiry_state=missing"
    echo "${label}_expiry_warning=missing"
    return 1
  fi

  if ! openssl x509 -in "${cert}" -noout >/dev/null 2>&1; then
    echo "${label}_present=true"
    echo "${label}_path=${cert}"
    echo "${label}_expiry_state=unparseable"
    echo "${label}_expiry_warning=unparseable"
    return 1
  fi

  echo "${label}_present=true"
  echo "${label}_path=${cert}"
  echo "${label}_subject=$(cert_subject "${cert}")"
  echo "${label}_issuer=$(cert_issuer "${cert}")"
  echo "${label}_not_after=$(cert_not_after "${cert}")"
  echo "${label}_sha256_fingerprint=$(cert_fingerprint "${cert}")"

  warn_seconds=$((WARN_DAYS * 24 * 60 * 60))
  if openssl x509 -in "${cert}" -noout -checkend 0 >/dev/null 2>&1; then
    echo "${label}_expiry_state=valid"
  else
    echo "${label}_expiry_state=expired"
    echo "${label}_expiry_warning=expired"
    return 1
  fi

  if openssl x509 -in "${cert}" -noout -checkend "${warn_seconds}" >/dev/null 2>&1; then
    echo "${label}_expiry_warning=none"
  else
    echo "${label}_expiry_warning=within_${WARN_DAYS}_days"
  fi
}

summary() {
  failed=0
  cat <<EOF
format=obos-tls-summary-v1
tls_dir=${TLS_DIR}
trust_export_dir=${EXPORT_DIR}
warn_days=${WARN_DAYS}
EOF
  cert_summary "${CA_CERT}" local_ca || failed=1
  cert_summary "${LEAF_CERT}" leaf || failed=1

  if [ -f "${EXPORT_DIR}/obos-local-ca.crt" ] &&
    [ -f "${EXPORT_DIR}/obos.local.crt" ] &&
    [ -f "${EXPORT_DIR}/trust-info.txt" ]; then
    echo "trust_export_present=true"
  else
    echo "trust_export_present=false"
  fi
  return "${failed}"
}

check_cert() {
  cert="$1"
  label="$2"

  [ -f "${cert}" ] || fail "${label} certificate missing: ${cert}"
  openssl x509 -in "${cert}" -noout >/dev/null 2>&1 ||
    fail "${label} certificate is not parseable: ${cert}"

  echo "${label}:"
  echo "  path: ${cert}"
  echo "  subject: $(cert_subject "${cert}")"
  echo "  issuer: $(cert_issuer "${cert}")"
  echo "  not_after: $(cert_not_after "${cert}")"
  echo "  sha256_fingerprint: $(cert_fingerprint "${cert}")"

  warn_seconds=$((WARN_DAYS * 24 * 60 * 60))
  if openssl x509 -in "${cert}" -noout -checkend 0 >/dev/null 2>&1; then
    echo "  expiry_state: valid"
  else
    echo "  expiry_state: expired"
    return 1
  fi

  if openssl x509 -in "${cert}" -noout -checkend "${warn_seconds}" >/dev/null 2>&1; then
    echo "  expiry_warning: none"
  else
    warn "${label} certificate expires within ${WARN_DAYS} days"
  fi
}

case "${1:-}" in
  summary)
    summary
    exit $?
    ;;
  -h|--help|help)
    echo "usage: check-tls-status.sh [summary]" >&2
    exit 2
    ;;
esac

failed=0
echo "TLS status:"
check_cert "${CA_CERT}" "local_ca" || failed=1
check_cert "${LEAF_CERT}" "leaf" || failed=1

if [ "${failed}" -eq 0 ]; then
  echo "tls status: PASS"
else
  echo "tls status: FAIL"
fi

exit "${failed}"
