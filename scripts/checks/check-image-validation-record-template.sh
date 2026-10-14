#!/usr/bin/env sh
set -eu

SCRIPT="scripts/images/print-image-validation-record-template.sh"

fail() {
  echo "image validation record template fixture failed: $1" >&2
  exit 1
}

iso_output="$(sh "${SCRIPT}" amd64-installer)"
amd64_output="$(sh "${SCRIPT}" amd64-vm)"
rpi_output="$(sh "${SCRIPT}" rpi4-arm64)"

printf '%s\n' "${iso_output}" | grep -q '^profile=amd64-installer$' \
  || fail "installer ISO template profile missing"
printf '%s\n' "${iso_output}" | grep -q '^boot_media=<usb|optical>$' \
  || fail "installer ISO template should prompt for USB or optical media"
printf '%s\n' "${iso_output}" | grep -q '^network_installer_used=no$' \
  || fail "installer ISO template should not use Network Installer"

printf '%s\n' "${amd64_output}" | grep -q '^profile=amd64-vm$' \
  || fail "amd64 template profile missing"
printf '%s\n' "${amd64_output}" | grep -q '^network_installer_used=no$' \
  || fail "amd64 template should not use Network Installer"
printf '%s\n' "${amd64_output}" | grep -q '^tls_leaf_renewal_plan_result=PASS$' \
  && fail "amd64 template prefilled TLS leaf renewal plan result"
printf '%s\n' "${amd64_output}" | grep -q '^tls_leaf_renewal_plan_result=<PASS|FAIL>$' \
  || fail "amd64 template should require TLS leaf renewal plan result"
printf '%s\n' "${amd64_output}" | grep -q '^signature_verified=<yes|no>$' \
  || fail "amd64 template should require signature verification result"

printf '%s\n' "${rpi_output}" | grep -q '^profile=rpi4-arm64$' \
  || fail "rpi template profile missing"
printf '%s\n' "${rpi_output}" | grep -q '^network_installer_used=yes$' \
  || fail "rpi template should require Network Installer"
printf '%s\n' "${rpi_output}" | grep -q '^boot_media=<sd|usb|nvme>$' \
  || fail "rpi template should prompt for supported boot media"

if sh "${SCRIPT}" unknown-profile >/dev/null 2>&1; then
  fail "unsupported profile was accepted"
fi

echo "image validation record template fixture: PASS"
