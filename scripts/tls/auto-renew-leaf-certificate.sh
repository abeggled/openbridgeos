#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
LEAF_CERT="${OBOS_TLS_LEAF_CERT:-${TLS_DIR}/obos.local.crt}"
OBOSCTL="${OBOS_TLS_OBOSCTL:-/usr/bin/obosctl}"
LEAF_VALIDITY_DAYS="${OBOS_TLS_LEAF_DAYS:-90}"
RENEW_AFTER_DAYS="${OBOS_TLS_RENEW_AFTER_DAYS:-47}"
ALLOW_NON_ROOT="${OBOS_ALLOW_NON_ROOT_TLS_AUTO_RENEWAL:-0}"

fail() {
  echo "automatic TLS leaf renewal failed: $1" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ] && [ "${ALLOW_NON_ROOT}" != "1" ]; then
  fail "auto-renew-leaf-certificate.sh must run as root"
fi
case "${LEAF_VALIDITY_DAYS}" in
  ''|*[!0-9]*|0) fail "OBOS_TLS_LEAF_DAYS must be a positive integer" ;;
esac
case "${RENEW_AFTER_DAYS}" in
  ''|*[!0-9]*|0) fail "OBOS_TLS_RENEW_AFTER_DAYS must be a positive integer" ;;
esac
[ "${RENEW_AFTER_DAYS}" -lt "${LEAF_VALIDITY_DAYS}" ] \
  || fail "OBOS_TLS_RENEW_AFTER_DAYS must be less than OBOS_TLS_LEAF_DAYS"
[ -x "${OBOSCTL}" ] || fail "obosctl is not executable: ${OBOSCTL}"
[ -f "${LEAF_CERT}" ] || fail "leaf certificate missing: ${LEAF_CERT}"
openssl x509 -in "${LEAF_CERT}" -noout >/dev/null 2>&1 \
  || fail "leaf certificate is not parseable: ${LEAF_CERT}"

not_before="$(openssl x509 -in "${LEAF_CERT}" -noout -startdate | sed 's/^notBefore=//')"
not_after="$(openssl x509 -in "${LEAF_CERT}" -noout -enddate | sed 's/^notAfter=//')"
not_before_epoch="$(date --date="${not_before}" +%s)" || fail "cannot parse leaf start date"
not_after_epoch="$(date --date="${not_after}" +%s)" || fail "cannot parse leaf end date"
maximum_seconds=$((LEAF_VALIDITY_DAYS * 24 * 60 * 60))
lifetime_seconds=$((not_after_epoch - not_before_epoch))
remaining_days=$((LEAF_VALIDITY_DAYS - RENEW_AFTER_DAYS))
renew_seconds=$((remaining_days * 24 * 60 * 60))

renewal_reason=
if [ "${lifetime_seconds}" -gt "${maximum_seconds}" ]; then
  renewal_reason=leaf_validity_exceeds_${LEAF_VALIDITY_DAYS}_days
elif ! openssl x509 -in "${LEAF_CERT}" -noout -checkend "${renew_seconds}" >/dev/null 2>&1; then
  renewal_reason=leaf_age_reached_${RENEW_AFTER_DAYS}_days
fi

if [ -z "${renewal_reason}" ]; then
  echo "format=obos-tls-auto-renewal-v1"
  echo "renewal_due=false"
  echo "leaf_validity_days=${LEAF_VALIDITY_DAYS}"
  echo "renew_after_days=${RENEW_AFTER_DAYS}"
  echo "result=PASS"
  exit 0
fi

echo "automatic TLS leaf renewal: ${renewal_reason}"
"${OBOSCTL}" tls-renew-leaf --confirm tls-renew-leaf
echo "format=obos-tls-auto-renewal-v1"
echo "renewal_due=true"
echo "renewal_reason=${renewal_reason}"
echo "result=PASS"
