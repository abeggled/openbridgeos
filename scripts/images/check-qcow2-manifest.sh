#!/usr/bin/env sh
set -eu

STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-0}"

fail() {
  echo "qcow2 manifest check failed: $1" >&2
  exit 1
}

warn() {
  echo "WARN $1" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

manifest_value() {
  key="$1"
  manifest_file="$2"

  awk -F= -v key="${key}" '
    $1 == key {
      print substr($0, length(key) + 2)
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "${manifest_file}" || fail "missing manifest key: ${key}"
}

expect_value() {
  key="$1"
  expected="$2"
  manifest_file="$3"
  actual="$(manifest_value "${key}" "${manifest_file}")"

  [ "${actual}" = "${expected}" ] \
    || fail "${key} must be ${expected}, got ${actual}"
}

check_hash() {
  label="$1"
  file_path="$2"
  expected_hash="$3"

  if [ ! -f "${file_path}" ]; then
    if [ "${STRICT_FILES}" = "1" ]; then
      fail "${label} file missing: ${file_path}"
    fi
    warn "${label} file missing, hash not checked: ${file_path}"
    return 0
  fi

  actual_hash="$(sha256sum "${file_path}" | cut -d ' ' -f 1)"
  [ "${actual_hash}" = "${expected_hash}" ] \
    || fail "${label} sha256 mismatch for ${file_path}"
}

[ "$#" -eq 1 ] || fail "usage: $0 <manifest>"
MANIFEST_FILE="$1"

require_command awk
require_command cut
require_command sha256sum

[ -f "${MANIFEST_FILE}" ] || fail "manifest not found: ${MANIFEST_FILE}"

expect_value format obos-qcow2-build-v1 "${MANIFEST_FILE}"
expect_value profile amd64-vm "${MANIFEST_FILE}"
expect_value architecture amd64 "${MANIFEST_FILE}"
expect_value output_format qcow2 "${MANIFEST_FILE}"
expect_value provision_script scripts/bootstrap/provision-debian.sh "${MANIFEST_FILE}"
expect_value first_boot_service obos-first-boot.service "${MANIFEST_FILE}"
expect_value ssh_default disabled "${MANIFEST_FILE}"
expect_value first_boot_pending true "${MANIFEST_FILE}"
expect_value contains_secrets false "${MANIFEST_FILE}"

image_path="$(manifest_value image "${MANIFEST_FILE}")"
image_sha256="$(manifest_value image_sha256 "${MANIFEST_FILE}")"
base_image_path="$(manifest_value base_image "${MANIFEST_FILE}")"
base_image_sha256="$(manifest_value base_image_sha256 "${MANIFEST_FILE}")"

[ -n "$(manifest_value created_at "${MANIFEST_FILE}")" ] || fail "created_at must not be empty"
[ -n "$(manifest_value debian_release "${MANIFEST_FILE}")" ] || fail "debian_release must not be empty"
[ -n "$(manifest_value base_image_url "${MANIFEST_FILE}")" ] || fail "base_image_url must not be empty"
[ -n "$(manifest_value repo_revision "${MANIFEST_FILE}")" ] || fail "repo_revision must not be empty"

check_hash image "${image_path}" "${image_sha256}"
check_hash base_image "${base_image_path}" "${base_image_sha256}"

echo "qcow2 manifest: PASS ${MANIFEST_FILE}"
