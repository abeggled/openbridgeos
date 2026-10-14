#!/usr/bin/env sh
set -eu

CHECKER="scripts/images/check-amd64-iso-runtime.sh"
BUILDER="scripts/images/build-amd64-installer-iso.sh"
RUNTIME_PACKAGES="packaging/images/obos-runtime-packages.list.chroot"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  echo "amd64 installer ISO runtime fixture failed: $1" >&2
  exit 1
}

[ -x "${CHECKER}" ] || fail "runtime checker missing"
[ -s "${RUNTIME_PACKAGES}" ] || fail "runtime package list missing"
grep -Fq 'config/package-lists/obos-runtime.list.chroot' "${BUILDER}" \
  || fail "ISO builder does not add the runtime packages to the install package set"
# The assertion intentionally searches for the builder's literal variable names.
# shellcheck disable=SC2016
grep -Fq 'sh "${RUNTIME_CHECK}" "${BUILD_DIR}" "${RUNTIME_PACKAGES}"' "${BUILDER}" \
  || fail "ISO builder does not validate the installed-system runtime"

mkdir -p "${TMP_DIR}/build/binary/live" \
  "${TMP_DIR}/build/binary/boot/grub" \
  "${TMP_DIR}/build/binary/install/gtk" \
  "${TMP_DIR}/build/chroot/usr/bin" \
  "${TMP_DIR}/build/chroot/usr/sbin" \
  "${TMP_DIR}/build/chroot/etc/nginx/sites-available"
: > "${TMP_DIR}/build/binary/live/filesystem.packages-remove"
: > "${TMP_DIR}/build/chroot/usr/bin/python3"
: > "${TMP_DIR}/build/chroot/usr/sbin/nginx"
chmod +x "${TMP_DIR}/build/chroot/usr/bin/python3" "${TMP_DIR}/build/chroot/usr/sbin/nginx"
cp packaging/images/amd64-installer/bootloaders/grub-pc/config.cfg \
  "${TMP_DIR}/build/binary/boot/grub/config.cfg"
cp packaging/images/amd64-installer/bootloaders/grub-pc/grub.cfg \
  "${TMP_DIR}/build/binary/boot/grub/grub.cfg"
sed 's|@KERNEL_GI@|/install/gtk/vmlinuz|; s|@INITRD_GI@|/install/gtk/initrd.gz|' \
  packaging/images/amd64-installer/bootloaders/grub-pc/install_start_gui.cfg \
  > "${TMP_DIR}/build/binary/boot/grub/install_start.cfg"
cp packaging/images/amd64-installer/preseed.cfg \
  "${TMP_DIR}/build/binary/install/preseed.cfg"
mkdir -p "${TMP_DIR}/initrd/usr/lib/obos-installer" \
  "${TMP_DIR}/initrd/usr/share/obos-installer"
cp packaging/images/amd64-installer/select-target-disk.sh \
  packaging/images/amd64-installer/finalize.sh \
  "${TMP_DIR}/initrd/usr/lib/obos-installer/"
cp packaging/images/amd64-installer/installer.templates \
  "${TMP_DIR}/initrd/usr/share/obos-installer/"
(cd "${TMP_DIR}/initrd" && find usr -print | cpio -o -H newc 2>/dev/null | gzip -c) \
  > "${TMP_DIR}/build/binary/install/gtk/initrd.gz"

while IFS= read -r package; do
  printf '%s\t1.0\n' "${package}"
done < "${RUNTIME_PACKAGES}" > "${TMP_DIR}/build/chroot.packages.install"
cp "${TMP_DIR}/build/chroot.packages.install" "${TMP_DIR}/build/chroot.packages.live"

sh "${CHECKER}" "${TMP_DIR}/build" "${RUNTIME_PACKAGES}" >/dev/null

sed -i '/^python3-minimal[[:space:]]/d' "${TMP_DIR}/build/chroot.packages.install"
if sh "${CHECKER}" "${TMP_DIR}/build" "${RUNTIME_PACKAGES}" >/dev/null 2>&1; then
  fail "checker accepted an installed system without python3-minimal"
fi

cp "${TMP_DIR}/build/chroot.packages.live" "${TMP_DIR}/build/chroot.packages.install"
printf '%s\n' nginx-light > "${TMP_DIR}/build/binary/live/filesystem.packages-remove"
if sh "${CHECKER}" "${TMP_DIR}/build" "${RUNTIME_PACKAGES}" >/dev/null 2>&1; then
  fail "checker accepted nginx removal by the live installer"
fi

echo "amd64 installer ISO runtime fixture: PASS"
