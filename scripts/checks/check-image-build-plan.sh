#!/usr/bin/env sh
set -eu

SCRIPT="scripts/images/print-image-build-plan.sh"

fail() {
  echo "image build plan fixture failed: $1" >&2
  exit 1
}

amd64_output="$(sh "${SCRIPT}" packaging/images/profiles/amd64-vm.env)"
rpi_output="$(sh "${SCRIPT}" packaging/images/profiles/rpi4-arm64.env)"

printf '%s\n' "${amd64_output}" | grep -q '^profile=amd64-vm$' \
  || fail "amd64 profile missing"
printf '%s\n' "${amd64_output}" | grep -q '^output_format=qcow2$' \
  || fail "amd64 output format missing"
printf '%s\n' "${amd64_output}" | grep -q '^default_ssh=disabled$' \
  || fail "amd64 SSH default missing"
printf '%s\n' "${amd64_output}" | grep -q 'qcow2_contract:' \
  || fail "amd64 qcow2 contract missing"

printf '%s\n' "${rpi_output}" | grep -q '^profile=rpi4-arm64$' \
  || fail "rpi profile missing"
printf '%s\n' "${rpi_output}" | grep -q '^rpi_network_installer_compatible=true$' \
  || fail "rpi Network Installer compatibility missing"
printf '%s\n' "${rpi_output}" | grep -q '^rpi_boot_media=sd,usb,nvme$' \
  || fail "rpi boot media missing"
printf '%s\n' "${rpi_output}" | grep -q 'CONFIG_BLK_DEV_NVME=y' \
  || fail "rpi NVMe kernel config missing"
printf '%s\n' "${rpi_output}" | grep -q 'rpi_contract:' \
  || fail "rpi contract missing"

if sh "${SCRIPT}" packaging/images/profiles/missing.env >/dev/null 2>&1; then
  fail "missing profile was accepted"
fi

echo "image build plan fixture: PASS"
