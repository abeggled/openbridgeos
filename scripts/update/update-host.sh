#!/usr/bin/env sh
set -eu

APT_GET="${OBOS_APT_GET:-apt-get}"
REBOOT_REQUIRED_FILE="${OBOS_REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
MODULES_DIR="${OBOS_MODULES_DIR:-/lib/modules}"
UNAME="${OBOS_UNAME:-uname}"
UPDATE_LOG_FILE="${OBOS_UPDATE_LOG_FILE:-/var/log/obos-update.log}"
POLICY_RC_D="${OBOS_POLICY_RC_D:-/usr/sbin/policy-rc.d}"
POLICY_RC_D_BACKUP="${POLICY_RC_D}.obos-update-original"
SERVICE_RESTART_INHIBIT_FILE="${OBOS_SERVICE_RESTART_INHIBIT_FILE:-/run/obos-update-inhibit-service-restarts}"
policy_active=false

fail() {
  echo "host update failed: $1" >&2
  exit 1
}

restore_service_restart_policy() {
  if [ "${policy_active}" = true ]; then
    rm -f "${SERVICE_RESTART_INHIBIT_FILE}" "${POLICY_RC_D}"
    if [ -e "${POLICY_RC_D_BACKUP}" ] || [ -L "${POLICY_RC_D_BACKUP}" ]; then
      mv "${POLICY_RC_D_BACKUP}" "${POLICY_RC_D}"
    fi
    policy_active=false
  fi
}

install_service_restart_policy() {
  for policy_path in "${POLICY_RC_D}" "${SERVICE_RESTART_INHIBIT_FILE}"; do
    printf '%s\n' "${policy_path}" | grep -Eq '^/[A-Za-z0-9._/-]+$' \
      || fail "service restart policy path is unsafe: ${policy_path}"
  done

  if [ -f "${POLICY_RC_D}" ] && grep -q '^# obos-update-policy-v1$' "${POLICY_RC_D}"; then
    rm -f "${POLICY_RC_D}"
    if [ -e "${POLICY_RC_D_BACKUP}" ] || [ -L "${POLICY_RC_D_BACKUP}" ]; then
      mv "${POLICY_RC_D_BACKUP}" "${POLICY_RC_D}"
    fi
  elif [ -e "${POLICY_RC_D_BACKUP}" ] || [ -L "${POLICY_RC_D_BACKUP}" ]; then
    fail "stale service restart policy backup exists: ${POLICY_RC_D_BACKUP}"
  fi

  install -d -m 0755 "$(dirname -- "${POLICY_RC_D}")" "$(dirname -- "${SERVICE_RESTART_INHIBIT_FILE}")"
  : > "${SERVICE_RESTART_INHIBIT_FILE}"
  chmod 0600 "${SERVICE_RESTART_INHIBIT_FILE}"
  policy_active=true
  if [ -e "${POLICY_RC_D}" ] || [ -L "${POLICY_RC_D}" ]; then
    mv "${POLICY_RC_D}" "${POLICY_RC_D_BACKUP}"
  fi
  policy_tmp="$(mktemp "${POLICY_RC_D}.obos-update.XXXXXX")"
  cat > "${policy_tmp}" <<EOF
#!/bin/sh
# obos-update-policy-v1
if [ -e "${SERVICE_RESTART_INHIBIT_FILE}" ]; then
  case "\${1:-}" in
    nginx|nginx.service) exit 101 ;;
  esac
fi
if [ -x "${POLICY_RC_D_BACKUP}" ]; then
  exec "${POLICY_RC_D_BACKUP}" "\$@"
fi
exit 0
EOF
  chmod 0755 "${policy_tmp}"
  mv "${policy_tmp}" "${POLICY_RC_D}"
}

[ "$(id -u)" -eq 0 ] || fail "must run as root"
command -v "${APT_GET}" >/dev/null 2>&1 || fail "apt-get is unavailable"
command -v "${UNAME}" >/dev/null 2>&1 || fail "uname is unavailable"
trap restore_service_restart_policy EXIT
trap 'exit 1' HUP INT TERM

export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 "$(dirname -- "${UPDATE_LOG_FILE}")"
touch "${UPDATE_LOG_FILE}"
chmod 0600 "${UPDATE_LOG_FILE}"

install_service_restart_policy

if ! "${APT_GET}" -q -o DPkg::Lock::Timeout=300 update >> "${UPDATE_LOG_FILE}" 2>&1; then
  tail -n 50 "${UPDATE_LOG_FILE}" >&2
  fail "APT metadata refresh failed; see ${UPDATE_LOG_FILE}"
fi
if ! "${APT_GET}" \
  -q \
  -o DPkg::Lock::Timeout=300 \
  -o Dpkg::Options::=--force-confold \
  --yes \
  --no-remove \
  full-upgrade >> "${UPDATE_LOG_FILE}" 2>&1; then
  tail -n 50 "${UPDATE_LOG_FILE}" >&2
  fail "APT full upgrade failed; see ${UPDATE_LOG_FILE}"
fi
restore_service_restart_policy

running_kernel="$(${UNAME} -r)"
latest_kernel=""
if [ -d "${MODULES_DIR}" ]; then
  latest_kernel="$(find "${MODULES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V | tail -n 1)"
fi

reboot_required=false
reboot_reason=none
if [ -e "${REBOOT_REQUIRED_FILE}" ]; then
  reboot_required=true
  reboot_reason=package-marker
elif [ -n "${latest_kernel}" ] && [ "${latest_kernel}" != "${running_kernel}" ]; then
  reboot_required=true
  reboot_reason=kernel-changed
fi

echo "format=obos-host-update-v1"
echo "os_packages_updated=true"
echo "running_kernel=${running_kernel}"
echo "latest_installed_kernel=${latest_kernel:-unknown}"
echo "reboot_required=${reboot_required}"
echo "reboot_reason=${reboot_reason}"
echo "update_log=${UPDATE_LOG_FILE}"
