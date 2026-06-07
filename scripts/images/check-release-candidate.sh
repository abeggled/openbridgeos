#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
CHECK_RELEASE_MANIFEST="${SCRIPT_DIR}/check-release-manifest.sh"
CHECK_VALIDATION_RECORD="${SCRIPT_DIR}/check-image-release-validation-record.sh"

fail() {
  echo "release candidate check failed: $1" >&2
  exit 1
}

value() {
  key="$1"
  file="$2"
  awk -F= -v key="${key}" '$1 == key { print substr($0, length($1) + 2); exit }' "${file}"
}

release_artifact_match() {
  profile="$1"
  artifact="$2"
  manifest="$3"
  artifact_count="$(value artifact_count "${release_manifest}")"
  i=1

  while [ "${i}" -le "${artifact_count}" ]; do
    prefix="artifact_${i}"
    release_profile="$(value "${prefix}_profile" "${release_manifest}")"
    release_image="$(value "${prefix}_image" "${release_manifest}")"
    release_manifest_path="$(value "${prefix}_manifest" "${release_manifest}")"
    if [ "${release_profile}" = "${profile}" ] &&
      [ "${release_image}" = "${artifact}" ] &&
      [ "${release_manifest_path}" = "${manifest}" ]; then
      return 0
    fi
    i=$((i + 1))
  done

  return 1
}

[ "$#" -ge 3 ] || fail "usage: $0 <release-manifest> <validation-record> <validation-record> [validation-record...]"

release_manifest="$1"
shift

[ -f "${CHECK_RELEASE_MANIFEST}" ] || fail "missing release manifest checker: ${CHECK_RELEASE_MANIFEST}"
[ -f "${CHECK_VALIDATION_RECORD}" ] || fail "missing validation record checker: ${CHECK_VALIDATION_RECORD}"

OBOS_MANIFEST_STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-1}" \
  OBOS_RELEASE_SIGNATURE_STRICT="${OBOS_RELEASE_SIGNATURE_STRICT:-1}" \
  OBOS_RELEASE_MINISIGN_PUBLIC_KEY="${OBOS_RELEASE_MINISIGN_PUBLIC_KEY:-}" \
  sh "${CHECK_RELEASE_MANIFEST}" "${release_manifest}" >/dev/null

amd64_validated=false
rpi_validated=false
record_count=0

for record in "$@"; do
  [ -f "${record}" ] || fail "validation record missing: ${record}"
  sh "${CHECK_VALIDATION_RECORD}" "${record}" >/dev/null
  profile="$(value profile "${record}")"
  artifact="$(value artifact "${record}")"
  manifest="$(value manifest "${record}")"
  release_artifact_match "${profile}" "${artifact}" "${manifest}" \
    || fail "validation record does not match release manifest artifact: ${record}"
  case "${profile}" in
    amd64-vm)
      [ "${amd64_validated}" = "false" ] \
        || fail "duplicate amd64-vm validation record: ${record}"
      amd64_validated=true
      ;;
    rpi4-arm64)
      [ "${rpi_validated}" = "false" ] \
        || fail "duplicate rpi4-arm64 validation record: ${record}"
      rpi_validated=true
      ;;
    *) fail "unsupported validation record profile: ${profile}" ;;
  esac
  record_count=$((record_count + 1))
done

[ "${amd64_validated}" = "true" ] || fail "amd64-vm validation record missing"
[ "${rpi_validated}" = "true" ] || fail "rpi4-arm64 validation record missing"
[ "${record_count}" -eq 2 ] || fail "release candidate must have exactly two validation records"

echo "format=obos-release-candidate-check-v1"
echo "release_manifest=${release_manifest}"
echo "validation_record_count=${record_count}"
echo "amd64_vm_validated=${amd64_validated}"
echo "rpi4_arm64_validated=${rpi_validated}"
echo "result=PASS"
