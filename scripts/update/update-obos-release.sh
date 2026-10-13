#!/usr/bin/env sh
set -eu

RELEASE_BASE_URL="${OBOS_RELEASE_BASE_URL:-https://github.com/abeggled/openbridgeos/releases/latest/download}"
RELEASE_BASE_URL_FILE="${OBOS_RELEASE_BASE_URL_FILE:-/etc/obos/update/release-base-url}"
PUBLIC_KEY_FILE="${OBOS_RELEASE_PUBLIC_KEY_FILE:-/etc/obos/update/minisign.pub}"
INSTALLED_VERSION_FILE="${OBOS_VERSION_FILE:-/etc/obos/version}"
INSTALLER="${OBOS_UPDATE_BUNDLE_INSTALLER:-/usr/lib/obos/install-update-bundle.sh}"
CURL="${OBOS_CURL:-curl}"
MINISIGN="${OBOS_MINISIGN:-minisign}"
MODE="${1:-apply}"

fail() {
  echo "OBOS release update failed: $1" >&2
  exit 1
}

manifest_value() {
  key="$1"
  file="$2"
  awk -F= -v key="${key}" '$1 == key { print substr($0, length(key) + 2); found=1; exit } END { if (!found) exit 1 }' "${file}" \
    || fail "manifest key missing: ${key}"
}

[ "${MODE}" = apply ] || [ "${MODE}" = check ] || fail "usage: update-obos-release.sh [check|apply]"
[ "${MODE}" = check ] || [ "$(id -u)" -eq 0 ] || fail "must run as root"

if [ -z "${OBOS_RELEASE_BASE_URL:-}" ] && [ -s "${RELEASE_BASE_URL_FILE}" ]; then
  RELEASE_BASE_URL="$(sed -n '1p' "${RELEASE_BASE_URL_FILE}")"
  case "${RELEASE_BASE_URL}" in
    https://github.com/abeggled/openbridgeos/releases/latest/download) ;;
    https://github.com/abeggled/openbridgeos/releases/download/*)
      release_tag="${RELEASE_BASE_URL#https://github.com/abeggled/openbridgeos/releases/download/}"
      printf '%s\n' "${release_tag}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._+-]*$' \
        || fail "configured release tag is invalid"
      ;;
    *) fail "configured release base URL is not an allowed openbridgeos GitHub release URL" ;;
  esac
fi

installed_version="$(cat "${INSTALLED_VERSION_FILE}" 2>/dev/null || printf '0.0.0')"

if [ ! -s "${PUBLIC_KEY_FILE}" ]; then
  echo "format=obos-release-update-v1"
  echo "release_status=not-configured"
  echo "installed_version=${installed_version}"
  echo "available_version=unknown"
  echo "update_available=false"
  echo "release_notes_present=false"
  echo "release_updated=false"
  echo "release_reboot_required=false"
  exit 0
fi

command -v "${CURL}" >/dev/null 2>&1 || fail "curl is unavailable"
command -v "${MINISIGN}" >/dev/null 2>&1 || fail "minisign is unavailable"
[ "${MODE}" = check ] || [ -x "${INSTALLER}" ] || fail "update bundle installer is unavailable"

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT HUP INT TERM
manifest="${work_dir}/obos-update.manifest"
signature="${manifest}.minisig"
archive="${work_dir}/obos-update.tar.gz"
notes="${work_dir}/obos-update-notes.txt"

http_code="$("${CURL}" -sS -L -o "${manifest}" -w '%{http_code}' "${RELEASE_BASE_URL}/obos-update.manifest")" \
  || fail "cannot query the latest GitHub release"
if [ "${http_code}" = 404 ]; then
  echo "format=obos-release-update-v1"
  echo "release_status=no-update-bundle"
  echo "installed_version=${installed_version}"
  echo "available_version=unknown"
  echo "update_available=false"
  echo "release_notes_present=false"
  echo "release_updated=false"
  echo "release_reboot_required=false"
  exit 0
fi
[ "${http_code}" = 200 ] || fail "manifest download returned HTTP ${http_code}"
"${CURL}" -fsSL -o "${signature}" "${RELEASE_BASE_URL}/obos-update.manifest.minisig"
"${MINISIGN}" -Vm "${manifest}" -x "${signature}" -p "${PUBLIC_KEY_FILE}" >/dev/null \
  || fail "release manifest signature verification failed"

[ "$(manifest_value format "${manifest}")" = obos-update-release-v1 ] \
  || fail "unsupported release manifest format"
version="$(manifest_value version "${manifest}")"
archive_name="$(manifest_value archive "${manifest}")"
archive_sha256="$(manifest_value archive_sha256 "${manifest}")"
root_dir="$(manifest_value root_dir "${manifest}")"
notes_name="$(manifest_value notes "${manifest}")"
notes_sha256="$(manifest_value notes_sha256 "${manifest}")"
[ "${archive_name}" = obos-update.tar.gz ] || fail "unexpected archive name"
[ "${notes_name}" = obos-update-notes.txt ] || fail "unexpected release notes name"
printf '%s\n' "${version}" | grep -Eq '^[0-9]+([.][0-9]+){1,3}([+~-][A-Za-z0-9.]+)?$' \
  || fail "release version is invalid"
[ "${root_dir}" = openbridgeos ] || fail "unexpected archive root"
printf '%s\n' "${archive_sha256}" | grep -Eq '^[a-f0-9]{64}$' \
  || fail "archive checksum is invalid"
printf '%s\n' "${notes_sha256}" | grep -Eq '^[a-f0-9]{64}$' \
  || fail "release notes checksum is invalid"

"${CURL}" -fsSL -o "${notes}" "${RELEASE_BASE_URL}/${notes_name}"
actual_notes_sha256="$(sha256sum "${notes}" | awk '{print $1}')"
[ "${actual_notes_sha256}" = "${notes_sha256}" ] || fail "release notes checksum mismatch"

update_available=true
release_status=available
if dpkg --compare-versions "${version}" le "${installed_version}"; then
  update_available=false
  release_status=current
fi

emit_release_summary() {
  echo "format=obos-release-update-v1"
  echo "release_status=${release_status}"
  echo "installed_version=${installed_version}"
  echo "available_version=${version}"
  echo "update_available=${update_available}"
  echo "release_notes_present=true"
  awk '
    NR <= 80 {
      gsub(/[^[:print:]\t]/, "")
      printf "release_note_%03d=%s\n", NR, substr($0, 1, 240)
      count=NR
    }
    END { printf "release_note_count=%d\n", count + 0 }
  ' "${notes}"
}

if [ "${MODE}" = check ]; then
  emit_release_summary
  echo "release_updated=false"
  echo "release_reboot_required=false"
  exit 0
fi

if [ "${update_available}" = false ]; then
  echo "format=obos-release-update-v1"
  echo "release_status=current"
  echo "release_version=${installed_version}"
  echo "release_updated=false"
  echo "release_reboot_required=false"
  exit 0
fi

"${CURL}" -fsSL -o "${archive}" "${RELEASE_BASE_URL}/${archive_name}"
actual_sha256="$(sha256sum "${archive}" | awk '{print $1}')"
[ "${actual_sha256}" = "${archive_sha256}" ] || fail "release archive checksum mismatch"

tar -tzf "${archive}" | awk '
  /^\// || /(^|\/)\.\.($|\/)/ { bad=1 }
  END { exit bad ? 1 : 0 }
' || fail "release archive contains unsafe paths"
if tar -tvzf "${archive}" | awk 'substr($1,1,1) ~ /[lh]/ { found=1 } END { exit found ? 0 : 1 }'; then
  fail "release archive contains links"
fi

tar -xzf "${archive}" --no-same-owner --no-same-permissions -C "${work_dir}"
[ -d "${work_dir}/${root_dir}" ] || fail "release archive root is missing"
"${INSTALLER}" "${work_dir}/${root_dir}" "${version}" >/dev/null

echo "format=obos-release-update-v1"
echo "release_status=updated"
echo "release_version=${version}"
echo "release_updated=true"
echo "release_reboot_required=true"
