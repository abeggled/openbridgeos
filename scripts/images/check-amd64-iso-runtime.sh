#!/usr/bin/env sh
set -eu

BUILD_DIR="${1:-}"
RUNTIME_PACKAGES="${2:-packaging/images/obos-runtime-packages.list.chroot}"
INSTALL_MANIFEST="${BUILD_DIR}/chroot.packages.install"
LIVE_MANIFEST="${BUILD_DIR}/chroot.packages.live"
REMOVE_MANIFEST="${BUILD_DIR}/binary/live/filesystem.packages-remove"
GRUB_CONFIG="${BUILD_DIR}/binary/boot/grub/config.cfg"
GRUB_MENU="${BUILD_DIR}/binary/boot/grub/grub.cfg"
GRUB_INSTALL_START="${BUILD_DIR}/binary/boot/grub/install_start.cfg"
INSTALLER_PRESEED="${BUILD_DIR}/binary/install/preseed.cfg"
INSTALLER_INITRD="${BUILD_DIR}/binary/install/gtk/initrd.gz"

fail() {
  echo "amd64 installer ISO runtime check failed: $1" >&2
  exit 1
}

[ -n "${BUILD_DIR}" ] || fail "usage: $0 <live-build-directory> [runtime-package-list]"
[ -s "${RUNTIME_PACKAGES}" ] || fail "runtime package list missing: ${RUNTIME_PACKAGES}"
[ -s "${INSTALL_MANIFEST}" ] || fail "installer package manifest missing: ${INSTALL_MANIFEST}"
[ -s "${LIVE_MANIFEST}" ] || fail "live package manifest missing: ${LIVE_MANIFEST}"

sort -c -u "${RUNTIME_PACKAGES}" 2>/dev/null \
  || fail "runtime package list must be sorted and contain no duplicates"
if grep -Ev '^[a-z0-9][a-z0-9+.-]*$' "${RUNTIME_PACKAGES}" >/dev/null; then
  fail "runtime package list contains an invalid package name"
fi

while IFS= read -r package; do
  grep -Eq "^${package}[[:space:]]" "${INSTALL_MANIFEST}" \
    || fail "${package} is absent from the installed-system package manifest"
  grep -Eq "^${package}[[:space:]]" "${LIVE_MANIFEST}" \
    || fail "${package} is absent from the live-system package manifest"
  if [ -f "${REMOVE_MANIFEST}" ] && grep -Fxq "${package}" "${REMOVE_MANIFEST}"; then
    fail "${package} is scheduled for removal by the live installer"
  fi
done < "${RUNTIME_PACKAGES}"

[ -x "${BUILD_DIR}/chroot/usr/bin/python3" ] \
  || fail "the built filesystem has no executable /usr/bin/python3"
[ -x "${BUILD_DIR}/chroot/usr/sbin/nginx" ] \
  || fail "the built filesystem has no executable /usr/sbin/nginx"
[ -d "${BUILD_DIR}/chroot/etc/nginx/sites-available" ] \
  || fail "the built filesystem has no nginx sites-available directory"

[ -s "${GRUB_CONFIG}" ] || fail "generated GRUB configuration is missing"
[ -s "${GRUB_MENU}" ] || fail "generated GRUB menu is missing"
[ -s "${GRUB_INSTALL_START}" ] || fail "generated automatic installer entry is missing"
[ -s "${INSTALLER_PRESEED}" ] || fail "generated installer preseed is missing"
[ -s "${INSTALLER_INITRD}" ] || fail "generated graphical installer initrd is missing"
grep -Eq '^set default=0$' "${GRUB_CONFIG}" \
  || fail "automatic installer is not the default GRUB entry"
grep -Eq '^set timeout=5$' "${GRUB_CONFIG}" \
  || fail "GRUB installer timeout is not five seconds"
grep -Fq 'source /boot/grub/install_start.cfg' "${GRUB_MENU}" \
  || fail "GRUB menu does not include the automatic installer entry"
grep -Fq 'auto=true priority=critical file=/cdrom/install/preseed.cfg' "${GRUB_INSTALL_START}" \
  || fail "automatic installer entry does not load the appliance preseed"
grep -Fq 'd-i partman/early_command string /usr/lib/obos-installer/select-target-disk.sh' "${INSTALLER_PRESEED}" \
  || fail "installer preseed does not invoke safe disk selection"
grep -Fq 'd-i preseed/late_command string /usr/lib/obos-installer/finalize.sh' "${INSTALLER_PRESEED}" \
  || fail "installer preseed does not invoke appliance finalization"

initrd_listing="$(mktemp)"
trap 'rm -f "${initrd_listing}"' EXIT HUP INT TERM
gzip -dc "${INSTALLER_INITRD}" | cpio -t 2>/dev/null > "${initrd_listing}" \
  || fail "cannot inspect generated graphical installer initrd"
for installer_file in \
  usr/lib/obos-installer/select-target-disk.sh \
  usr/lib/obos-installer/finalize.sh \
  usr/share/obos-installer/installer.templates; do
  grep -Fxq "${installer_file}" "${initrd_listing}" \
    || fail "${installer_file} is absent from the graphical installer initrd"
done

echo "amd64 installer ISO runtime: PASS"
