#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
CHECK_RELEASE_CANDIDATE="${SCRIPT_DIR}/check-release-candidate.sh"

fail() {
  echo "release evidence bundle check failed: $1" >&2
  exit 1
}

first_content_line() {
  file="$1"
  awk 'NF && $1 !~ /^#/ { print; exit }' "${file}"
}

require_file() {
  file="$1"
  [ -f "${file}" ] || fail "missing required release evidence file: ${file}"
  [ -s "${file}" ] || fail "required release evidence file is empty: ${file}"
}

require_notes_line() {
  expected="$1"
  grep -Fq -- "${expected}" "${release_notes}" \
    || fail "release notes missing required evidence reference: ${expected}"
}

notes_value() {
  key="$1"
  awk -F= -v key="${key}" '$1 == key { print substr($0, length($1) + 2); exit }' "${release_notes}"
}

require_notes_value() {
  key="$1"
  value="$(notes_value "${key}")"
  [ -n "${value}" ] || fail "release notes ${key} is missing or empty"
  case "${value}" in
    \<*\>) fail "release notes ${key} still contains a template placeholder" ;;
  esac
}

[ "$#" -eq 1 ] || fail "usage: $0 <release-evidence-dir>"

bundle_dir="$1"
[ -d "${bundle_dir}" ] || fail "release evidence directory not found: ${bundle_dir}"
[ -f "${CHECK_RELEASE_CANDIDATE}" ] || fail "missing release candidate checker: ${CHECK_RELEASE_CANDIDATE}"

release_manifest="${bundle_dir}/obos-release.manifest"
release_signature="${release_manifest}.minisig"
release_public_key="${bundle_dir}/obos-release.minisign.pub"
release_notes="${bundle_dir}/release-notes.md"
amd64_record="${bundle_dir}/validation-amd64-vm.record"
rpi_record="${bundle_dir}/validation-rpi4-arm64.record"

require_file "${release_manifest}"
require_file "${release_signature}"
require_file "${release_public_key}"
require_file "${release_notes}"
require_file "${amd64_record}"
require_file "${rpi_record}"

public_key="$(first_content_line "${release_public_key}")"
[ -n "${public_key}" ] || fail "release public key file does not contain a public key"

require_notes_value "minisign_public_key"
[ "$(notes_value minisign_public_key)" = "${public_key}" ] \
  || fail "release notes minisign_public_key does not match release public key file"
require_notes_value "minisign_public_key_fingerprint"
require_notes_line "obos-release.manifest"
require_notes_line "obos-release.manifest.minisig"
require_notes_line "obos-release.minisign.pub"
require_notes_line "profile=amd64-vm"
require_notes_line "profile=rpi4-arm64"
require_notes_line "validation-amd64-vm.record"
require_notes_line "validation-rpi4-arm64.record"
require_notes_value "tls_leaf_renewal_plan_result"
require_notes_value "compose_image_pinning"
require_notes_line "Known Gaps"
require_notes_line "Upgrade And Migration Notes"
require_notes_line "raw unencrypted backups"

OBOS_RELEASE_MINISIGN_PUBLIC_KEY="${public_key}" \
  sh "${CHECK_RELEASE_CANDIDATE}" "${release_manifest}" "${amd64_record}" "${rpi_record}" >/dev/null

echo "format=obos-release-evidence-bundle-check-v1"
echo "bundle_dir=${bundle_dir}"
echo "release_manifest=${release_manifest}"
echo "release_notes=${release_notes}"
echo "validation_record_count=2"
echo "result=PASS"
