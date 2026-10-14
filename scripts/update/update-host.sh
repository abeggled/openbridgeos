#!/usr/bin/env sh
set -eu

APT_GET="${OBOS_APT_GET:-apt-get}"
REBOOT_REQUIRED_FILE="${OBOS_REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
MODULES_DIR="${OBOS_MODULES_DIR:-/lib/modules}"
UNAME="${OBOS_UNAME:-uname}"
UPDATE_LOG_FILE="${OBOS_UPDATE_LOG_FILE:-/var/log/obos-update.log}"
PENDING_NGINX_CONFIG="${OBOS_PENDING_NGINX_CONFIG:-/etc/obos/update/openbridgeserver.conf.pending}"
DISABLE_INSTALL_MEDIA_SOURCES="${OBOS_DISABLE_INSTALL_MEDIA_SOURCES:-/usr/lib/obos/disable-install-media-sources.sh}"

fail() {
  echo "host update failed: $1" >&2
  exit 1
}

[ "$(id -u)" -eq 0 ] || fail "must run as root"
command -v "${APT_GET}" >/dev/null 2>&1 || fail "apt-get is unavailable"
command -v "${UNAME}" >/dev/null 2>&1 || fail "uname is unavailable"

export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 "$(dirname -- "${UPDATE_LOG_FILE}")"
touch "${UPDATE_LOG_FILE}"
chmod 0600 "${UPDATE_LOG_FILE}"

if [ -x "${DISABLE_INSTALL_MEDIA_SOURCES}" ]; then
  "${DISABLE_INSTALL_MEDIA_SOURCES}" >> "${UPDATE_LOG_FILE}" 2>&1
fi

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
elif [ -s "${PENDING_NGINX_CONFIG}" ]; then
  reboot_required=true
  reboot_reason=obos-release-pending
fi

echo "format=obos-host-update-v1"
echo "os_packages_updated=true"
echo "running_kernel=${running_kernel}"
echo "latest_installed_kernel=${latest_kernel:-unknown}"
echo "reboot_required=${reboot_required}"
echo "reboot_reason=${reboot_reason}"
echo "update_log=${UPDATE_LOG_FILE}"
