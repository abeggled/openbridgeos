#!/usr/bin/env sh
set -eu

record="${1:-}"

fail() {
  echo "image release validation record failed: $1" >&2
  exit 1
}

[ -n "${record}" ] || fail "validation record path is required"
[ -f "${record}" ] || fail "validation record not found: ${record}"

value() {
  key="$1"
  awk -F= -v key="${key}" '$1 == key { print substr($0, length($1) + 2); exit }' "${record}"
}

require_present() {
  key="$1"
  val="$(value "${key}")"
  [ -n "${val}" ] || fail "${key} is missing"
}

require_value() {
  key="$1"
  expected="$2"
  val="$(value "${key}")"
  [ "${val}" = "${expected}" ] || fail "${key} must be ${expected}"
}

require_any() {
  key="$1"
  expected_a="$2"
  expected_b="$3"
  val="$(value "${key}")"
  [ "${val}" = "${expected_a}" ] || [ "${val}" = "${expected_b}" ] \
    || fail "${key} must be ${expected_a} or ${expected_b}"
}

require_value format obos-image-release-validation-v1
require_present release_candidate
require_present profile
require_present artifact
require_present manifest
require_present platform
require_present hardware_or_vm
require_present boot_media

require_value signature_verified yes
require_value checksums_verified yes
require_value first_boot_completed yes
require_value ssh_default_disabled yes
require_value security_summary_result PASS
require_value mvp_readiness_result PASS
require_value tls_leaf_renewal_plan_result PASS
require_value tls_trust_exported yes
require_value rollback_stage_result PASS
require_any network_installer_used yes no

profile="$(value profile)"
case "${profile}" in
  amd64-vm)
    require_value network_installer_used no
    ;;
  rpi4-arm64)
    require_value network_installer_used yes
    case "$(value boot_media)" in
      sd|usb|nvme) ;;
      *) fail "rpi4-arm64 boot_media must be sd, usb, or nvme" ;;
    esac
    ;;
  *)
    fail "unsupported profile: ${profile}"
    ;;
esac

echo "format=obos-image-release-validation-check-v1"
echo "record=${record}"
echo "profile=${profile}"
echo "result=PASS"
