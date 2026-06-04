#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
EXPORT_DIR="${OBOS_TRUST_EXPORT_DIR:-/srv/obos/state/trust}"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_CERT="${TLS_DIR}/obos.local.crt"
TRUST_INFO="${EXPORT_DIR}/trust-info.txt"
CA_EXPORT="${EXPORT_DIR}/obos-local-ca.crt"
LEAF_EXPORT="${EXPORT_DIR}/obos.local.crt"
TRUST_INFO_SCRIPT="${OBOS_TLS_INFO_SCRIPT:-/usr/lib/obos/print-trust-info.sh}"

if [ "$(id -u)" -ne 0 ]; then
  echo "export-trust-bundle.sh must run as root" >&2
  exit 1
fi

if [ ! -f "${CA_CERT}" ] || [ ! -f "${LEAF_CERT}" ]; then
  echo "TLS material not found in ${TLS_DIR}" >&2
  echo "Run generate-tls-material.sh first." >&2
  exit 1
fi

install -d -m 0755 "${EXPORT_DIR}"
install -m 0644 "${CA_CERT}" "${CA_EXPORT}"
install -m 0644 "${LEAF_CERT}" "${LEAF_EXPORT}"

if [ -x "${TRUST_INFO_SCRIPT}" ]; then
  "${TRUST_INFO_SCRIPT}" > "${TRUST_INFO}"
else
  openssl x509 -in "${CA_CERT}" -noout -fingerprint -sha256 > "${TRUST_INFO}"
  openssl x509 -in "${LEAF_CERT}" -noout -fingerprint -sha256 >> "${TRUST_INFO}"
fi

chmod 0644 "${TRUST_INFO}"

cat <<EOF
Trust bundle exported to ${EXPORT_DIR}

Files:
- ${CA_EXPORT}
- ${LEAF_EXPORT}
- ${TRUST_INFO}

No private keys were exported.
EOF
