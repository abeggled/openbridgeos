#!/usr/bin/env sh
set -eu

STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-0}"

fail() {
  echo "release manifest check failed: $1" >&2
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

check_checksum_file() {
  checksum_file="$1"
  expected_hash="$2"

  if [ ! -f "${checksum_file}" ]; then
    if [ "${STRICT_FILES}" = "1" ]; then
      fail "checksum file missing: ${checksum_file}"
    fi
    warn "checksum file missing, content not checked: ${checksum_file}"
    return 0
  fi

  actual_hash="$(cut -d ' ' -f 1 < "${checksum_file}")"
  [ "${actual_hash}" = "${expected_hash}" ] \
    || fail "checksum file sha256 mismatch for ${checksum_file}"
}

check_image_manifest() {
  manifest_file="$1"
  expected_profile="$2"
  expected_image="$3"
  expected_checksum_file="$4"
  expected_image_sha256="$5"

  [ -f "${manifest_file}" ] || fail "image manifest missing: ${manifest_file}"
  format="$(manifest_value format "${manifest_file}")"
  case "${format}" in
    obos-qcow2-build-v1|obos-rpi-image-build-v1) ;;
    *) fail "unsupported image manifest format: ${format}" ;;
  esac

  expect_value release_build 1 "${manifest_file}"
  expect_value profile "${expected_profile}" "${manifest_file}"
  expect_value image "${expected_image}" "${manifest_file}"
  expect_value checksum_file "${expected_checksum_file}" "${manifest_file}"
  expect_value image_sha256 "${expected_image_sha256}" "${manifest_file}"

  checksum_file="$(manifest_value checksum_file "${manifest_file}")"
  check_checksum_file "${checksum_file}" "${expected_image_sha256}"
}

[ "$#" -eq 1 ] || fail "usage: $0 <release-manifest>"
MANIFEST_FILE="$1"

require_command awk
require_command cut

[ -f "${MANIFEST_FILE}" ] || fail "manifest not found: ${MANIFEST_FILE}"

expect_value format obos-release-bundle-v1 "${MANIFEST_FILE}"
[ -n "$(manifest_value created_at "${MANIFEST_FILE}")" ] || fail "created_at must not be empty"
[ -n "$(manifest_value repo_revision "${MANIFEST_FILE}")" ] || fail "repo_revision must not be empty"

artifact_count="$(manifest_value artifact_count "${MANIFEST_FILE}")"
case "${artifact_count}" in
  ''|*[!0-9]*) fail "artifact_count must be a positive integer" ;;
  0) fail "artifact_count must be greater than zero" ;;
esac

i=1
while [ "${i}" -le "${artifact_count}" ]; do
  prefix="artifact_${i}"
  profile="$(manifest_value "${prefix}_profile" "${MANIFEST_FILE}")"
  image="$(manifest_value "${prefix}_image" "${MANIFEST_FILE}")"
  checksum_file="$(manifest_value "${prefix}_checksum_file" "${MANIFEST_FILE}")"
  image_sha256="$(manifest_value "${prefix}_image_sha256" "${MANIFEST_FILE}")"
  image_manifest="$(manifest_value "${prefix}_manifest" "${MANIFEST_FILE}")"

  [ -n "${image}" ] || fail "${prefix}_image must not be empty"
  [ -n "${checksum_file}" ] || fail "${prefix}_checksum_file must not be empty"
  check_image_manifest "${image_manifest}" "${profile}" "${image}" "${checksum_file}" "${image_sha256}"
  i=$((i + 1))
done

echo "release manifest: PASS ${MANIFEST_FILE}"
