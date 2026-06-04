#!/usr/bin/env sh
set -eu

TLS_DIR="${OBOS_TLS_DIR:-/etc/obos/tls}"
CA_CERT="${TLS_DIR}/obos-local-ca.crt"
LEAF_CERT="${TLS_DIR}/obos.local.crt"

fingerprint() {
  cert="$1"
  openssl x509 -in "${cert}" -noout -fingerprint -sha256 | sed 's/^sha256 Fingerprint=//; s/^SHA256 Fingerprint=//'
}

if [ ! -f "${CA_CERT}" ] || [ ! -f "${LEAF_CERT}" ]; then
  echo "TLS material not found in ${TLS_DIR}" >&2
  echo "Run generate-tls-material.sh first." >&2
  exit 1
fi

hostname_value="$(hostname)"
ip_addresses="$(hostname -I 2>/dev/null | xargs || true)"

cat <<EOF
open bridge operating system TLS trust information

Appliance hostname: ${hostname_value}
Appliance IPs:      ${ip_addresses:-unknown}

Local CA certificate: ${CA_CERT}
Leaf certificate:     ${LEAF_CERT}

Local CA SHA-256 fingerprint:
$(fingerprint "${CA_CERT}")

Leaf certificate SHA-256 fingerprint:
$(fingerprint "${LEAF_CERT}")

Trust model:
- This local CA is unique to this appliance instance.
- Install the local CA certificate on client devices only if you trust this appliance instance.
- Do not reuse this CA on other appliances.
- Treat exported CA material and backups as sensitive.
EOF
