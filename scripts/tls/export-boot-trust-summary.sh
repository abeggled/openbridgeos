#!/usr/bin/env sh
set -eu

TRUST_EXPORT_DIR="${OBOS_TRUST_EXPORT_DIR:-/srv/obos/state/trust}"
TRUST_INFO="${TRUST_EXPORT_DIR}/trust-info.txt"
CA_EXPORT="${TRUST_EXPORT_DIR}/obos-local-ca.crt"
WEB_AUTH_INFO_FILE="${OBOS_WEB_AUTH_INFO_FILE:-/etc/obos/web-admin.env}"
BOOT_TRUST_DIR="${OBOS_BOOT_TRUST_DIR:-}"
SUMMARY_NAME="${OBOS_BOOT_TRUST_SUMMARY_NAME:-OBOS-TRUST.txt}"
CA_NAME="${OBOS_BOOT_TRUST_CA_NAME:-OBOS-LOCAL-CA.crt}"
ONBOARDING_NAME="${OBOS_BOOT_ONBOARDING_NAME:-OBOS-ONBOARDING.txt}"

if [ "$(id -u)" -ne 0 ]; then
  echo "export-boot-trust-summary.sh must run as root" >&2
  exit 1
fi

is_mountpoint() {
  path="$1"
  if command -v findmnt >/dev/null 2>&1; then
    findmnt --mountpoint "${path}" >/dev/null 2>&1
  elif command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "${path}"
  else
    return 1
  fi
}

select_boot_dir() {
  if [ -n "${BOOT_TRUST_DIR}" ]; then
    [ -d "${BOOT_TRUST_DIR}" ] && [ -w "${BOOT_TRUST_DIR}" ] && return 0
    echo "configured boot trust directory is not writable: ${BOOT_TRUST_DIR}" >&2
    return 1
  fi

  for candidate in /boot/firmware /boot/efi /boot; do
    if [ -d "${candidate}" ] && [ -w "${candidate}" ] && is_mountpoint "${candidate}"; then
      BOOT_TRUST_DIR="${candidate}"
      return 0
    fi
  done

  return 1
}

if ! select_boot_dir; then
  echo "No writable boot-accessible trust directory found; skipping boot trust summary."
  exit 0
fi

if [ ! -f "${TRUST_INFO}" ] || [ ! -f "${CA_EXPORT}" ]; then
  echo "trust export files not found in ${TRUST_EXPORT_DIR}" >&2
  echo "Run export-trust-bundle.sh first." >&2
  exit 1
fi

summary_target="${BOOT_TRUST_DIR}/${SUMMARY_NAME}"
ca_target="${BOOT_TRUST_DIR}/${CA_NAME}"
onboarding_target="${BOOT_TRUST_DIR}/${ONBOARDING_NAME}"
onboarding_exported=false

{
  cat "${TRUST_INFO}"
  cat <<EOF

Boot-accessible trust files:
- ${summary_target}
- ${ca_target}

No private keys were exported to the boot partition.
EOF
} > "${summary_target}"

install -m 0644 "${CA_EXPORT}" "${ca_target}"
chmod 0644 "${summary_target}"

if [ -f "${WEB_AUTH_INFO_FILE}" ]; then
  admin_user="$(sed -n 's/^OBOS_WEB_ADMIN_USER=//p' "${WEB_AUTH_INFO_FILE}" | head -n 1)"
  admin_password="$(sed -n 's/^OBOS_WEB_ADMIN_PASSWORD=//p' "${WEB_AUTH_INFO_FILE}" | head -n 1)"
  cat > "${onboarding_target}" <<EOF
open bridge operating system onboarding

URL:
- https://obos.local/obos/

Initial web console credentials:
- username: ${admin_user:-admin}
- password: ${admin_password:-unknown}

Security note:
- This file contains the initial web console password.
- Rotate the web console password after onboarding.
- Remove it from the boot-accessible partition after onboarding.
EOF
  chmod 0644 "${onboarding_target}"
  onboarding_exported=true
fi

if [ "${onboarding_exported}" = true ]; then
  onboarding_line="- ${onboarding_target}"
  onboarding_note="The onboarding file contains the initial web console password and should be removed after onboarding."
else
  onboarding_line="- onboarding credentials not exported because ${WEB_AUTH_INFO_FILE} is missing"
  onboarding_note="No onboarding password file was exported."
fi

cat <<EOF
Boot trust summary exported to ${BOOT_TRUST_DIR}

Files:
- ${summary_target}
- ${ca_target}
${onboarding_line}

No private keys were exported. ${onboarding_note}
EOF
