#!/usr/bin/env sh
set -eu

STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-0}"

fail() {
  echo "amd64 ISO manifest check failed: $1" >&2
  exit 1
}

manifest_value() {
  key="$1"
  manifest_file="$2"
  awk -F= -v key="${key}" '$1 == key { print substr($0, length(key) + 2); found=1; exit } END { if (!found) exit 1 }' "${manifest_file}" \
    || fail "missing manifest key: ${key}"
}

expect_value() {
  actual="$(manifest_value "$1" "$3")"
  [ "${actual}" = "$2" ] || fail "$1 must be $2, got ${actual}"
}

[ "$#" -eq 1 ] || fail "usage: $0 <manifest>"
MANIFEST_FILE="$1"
[ -f "${MANIFEST_FILE}" ] || fail "manifest not found: ${MANIFEST_FILE}"

expect_value format obos-amd64-iso-build-v1 "${MANIFEST_FILE}"
expect_value profile amd64-installer "${MANIFEST_FILE}"
expect_value architecture amd64 "${MANIFEST_FILE}"
expect_value debian_release trixie "${MANIFEST_FILE}"
expect_value output_format iso "${MANIFEST_FILE}"
expect_value image_extension iso "${MANIFEST_FILE}"
expect_value hybrid true "${MANIFEST_FILE}"
expect_value boot_targets bios,uefi "${MANIFEST_FILE}"
expect_value installer_mode live "${MANIFEST_FILE}"
expect_value provision_script scripts/bootstrap/provision-debian.sh "${MANIFEST_FILE}"
expect_value first_boot_service obos-first-boot.service "${MANIFEST_FILE}"
expect_value ssh_default disabled "${MANIFEST_FILE}"
expect_value first_boot_pending true "${MANIFEST_FILE}"
expect_value contains_secrets false "${MANIFEST_FILE}"

release_build="$(manifest_value release_build "${MANIFEST_FILE}")"
case "${release_build}" in 0|1) ;; *) fail "release_build must be 0 or 1" ;; esac
repo_dirty="$(manifest_value repo_dirty "${MANIFEST_FILE}")"
[ "${release_build}" != 1 ] || [ "${repo_dirty}" = false ] || fail "release builds must record repo_dirty=false"

image="$(manifest_value image "${MANIFEST_FILE}")"
checksum="$(manifest_value checksum_file "${MANIFEST_FILE}")"
expected_sha="$(manifest_value image_sha256 "${MANIFEST_FILE}")"
[ -n "$(manifest_value created_at "${MANIFEST_FILE}")" ] || fail "created_at must not be empty"
[ -n "$(manifest_value repo_revision "${MANIFEST_FILE}")" ] || fail "repo_revision must not be empty"

if [ "${STRICT_FILES}" = 1 ]; then
  [ -s "${image}" ] || fail "image missing: ${image}"
  [ -s "${checksum}" ] || fail "checksum missing: ${checksum}"
  actual_sha="$(sha256sum "${image}" | cut -d ' ' -f 1)"
  [ "${actual_sha}" = "${expected_sha}" ] || fail "image checksum mismatch"
  [ "$(cut -d ' ' -f 1 < "${checksum}")" = "${expected_sha}" ] || fail "checksum file mismatch"
fi

echo "amd64 ISO manifest: PASS ${MANIFEST_FILE}"
