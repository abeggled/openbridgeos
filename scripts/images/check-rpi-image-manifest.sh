#!/usr/bin/env sh
set -eu

STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-0}"

fail() {
  echo "Raspberry Pi image manifest check failed: $1" >&2
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

contains_csv_value() {
  values="$1"
  expected="$2"
  case ",${values}," in
    *,${expected},*) return 0 ;;
    *) return 1 ;;
  esac
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

[ "$#" -eq 1 ] || fail "usage: $0 <manifest>"
MANIFEST_FILE="$1"

require_command awk
require_command cut
require_command sha256sum

[ -f "${MANIFEST_FILE}" ] || fail "manifest not found: ${MANIFEST_FILE}"

expect_value format obos-rpi-image-build-v1 "${MANIFEST_FILE}"
expect_value profile rpi4-arm64 "${MANIFEST_FILE}"
expect_value architecture arm64 "${MANIFEST_FILE}"
expect_value debian_release trixie "${MANIFEST_FILE}"
expect_value output_format raw "${MANIFEST_FILE}"
expect_value output_compression xz "${MANIFEST_FILE}"
expect_value image_extension img.xz "${MANIFEST_FILE}"
expect_value network_installer_compatible true "${MANIFEST_FILE}"
expect_value firmware_mode raspberry-pi-bootloader "${MANIFEST_FILE}"
expect_value partition_layout boot-fat32,root-ext4 "${MANIFEST_FILE}"
expect_value boot_partition_label OBOSBOOT "${MANIFEST_FILE}"
expect_value root_partition_label OBOSROOT "${MANIFEST_FILE}"
expect_value kernel_config_verified true "${MANIFEST_FILE}"
expect_value provision_script scripts/bootstrap/provision-debian.sh "${MANIFEST_FILE}"
expect_value first_boot_service obos-first-boot.service "${MANIFEST_FILE}"
expect_value ssh_default disabled "${MANIFEST_FILE}"
expect_value first_boot_pending true "${MANIFEST_FILE}"
expect_value contains_secrets false "${MANIFEST_FILE}"

release_build="$(manifest_value release_build "${MANIFEST_FILE}")"
case "${release_build}" in
  0|1) ;;
  *) fail "release_build must be 0 or 1, got ${release_build}" ;;
esac

repo_dirty="$(manifest_value repo_dirty "${MANIFEST_FILE}")"
case "${repo_dirty}" in
  true|false|unknown) ;;
  *) fail "repo_dirty must be true, false, or unknown, got ${repo_dirty}" ;;
esac
[ "${release_build}" != "1" ] || [ "${repo_dirty}" = "false" ] \
  || fail "release builds must record repo_dirty=false"

boot_media="$(manifest_value boot_media "${MANIFEST_FILE}")"
contains_csv_value "${boot_media}" sd || fail "boot_media must include sd"
contains_csv_value "${boot_media}" usb || fail "boot_media must include usb"
contains_csv_value "${boot_media}" nvme || fail "boot_media must include nvme"

required_kernel_config="$(manifest_value kernel_required_config "${MANIFEST_FILE}")"
contains_csv_value "${required_kernel_config}" 'CONFIG_BLK_DEV_NVME=y' \
  || fail "kernel_required_config must include CONFIG_BLK_DEV_NVME=y"
contains_csv_value "${required_kernel_config}" 'CONFIG_PCIE_BRCMSTB=y' \
  || fail "kernel_required_config must include CONFIG_PCIE_BRCMSTB=y"
contains_csv_value "${required_kernel_config}" 'CONFIG_USB_XHCI_PCI=y' \
  || fail "kernel_required_config must include CONFIG_USB_XHCI_PCI=y"

image_path="$(manifest_value image "${MANIFEST_FILE}")"
checksum_file="$(manifest_value checksum_file "${MANIFEST_FILE}")"
image_sha256="$(manifest_value image_sha256 "${MANIFEST_FILE}")"

[ -n "$(manifest_value created_at "${MANIFEST_FILE}")" ] || fail "created_at must not be empty"
[ -n "$(manifest_value repo_revision "${MANIFEST_FILE}")" ] || fail "repo_revision must not be empty"

check_hash image "${image_path}" "${image_sha256}"
check_checksum_file "${checksum_file}" "${image_sha256}"

echo "Raspberry Pi image manifest: PASS ${MANIFEST_FILE}"
