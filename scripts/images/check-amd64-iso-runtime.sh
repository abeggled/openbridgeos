#!/usr/bin/env sh
set -eu

BUILD_DIR="${1:-}"
RUNTIME_PACKAGES="${2:-packaging/images/obos-runtime-packages.list.chroot}"
INSTALL_MANIFEST="${BUILD_DIR}/chroot.packages.install"
LIVE_MANIFEST="${BUILD_DIR}/chroot.packages.live"
REMOVE_MANIFEST="${BUILD_DIR}/binary/live/filesystem.packages-remove"

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

echo "amd64 installer ISO runtime: PASS"
