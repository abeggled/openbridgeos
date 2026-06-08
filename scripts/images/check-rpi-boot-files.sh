#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/rpi4-arm64.env}"

fail() {
  echo "Raspberry Pi boot files check failed: $1" >&2
  exit 1
}

pass() {
  printf 'PASS %s\n' "$1"
}

check_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

check_line() {
  expected="$1"
  file="$2"
  grep -Fq -- "${expected}" "${file}" \
    || fail "missing '${expected}' in ${file}"
  pass "${expected}"
}

check_cmdline_token() {
  token="$1"
  file="$2"
  tr ' ' '\n' < "${file}" | grep -Fxq -- "${token}" \
    || fail "missing cmdline token '${token}' in ${file}"
  pass "cmdline ${token}"
}

[ "$#" -eq 1 ] || fail "usage: $0 <mounted-root>"
ROOT_DIR="$1"

[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_KIND=
OBOS_RPI_BOOT_PARTITION_LABEL=
OBOS_RPI_ROOT_PARTITION_LABEL=

# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = "rpi4-arm64" ] || fail "profile must be rpi4-arm64"
[ "${OBOS_IMAGE_KIND}" = "rpi-image" ] || fail "profile must describe a Raspberry Pi image"
[ -n "${OBOS_RPI_BOOT_PARTITION_LABEL}" ] || fail "profile must define boot partition label"
[ -n "${OBOS_RPI_ROOT_PARTITION_LABEL}" ] || fail "profile must define root partition label"

FSTAB="${ROOT_DIR}/etc/fstab"
CONFIG_TXT="${ROOT_DIR}/boot/config.txt"
CMDLINE_TXT="${ROOT_DIR}/boot/cmdline.txt"
INITRAMFS_MODULES="${ROOT_DIR}/etc/initramfs-tools/modules"

check_file "${FSTAB}"
check_file "${CONFIG_TXT}"
check_file "${CMDLINE_TXT}"
check_file "${INITRAMFS_MODULES}"

check_line "LABEL=${OBOS_RPI_ROOT_PARTITION_LABEL} / ext4 defaults,noatime 0 1" "${FSTAB}"
check_line "LABEL=${OBOS_RPI_BOOT_PARTITION_LABEL} /boot vfat defaults 0 2" "${FSTAB}"
check_line "arm_64bit=1" "${CONFIG_TXT}"
check_line "auto_initramfs=1" "${CONFIG_TXT}"
check_cmdline_token "root=LABEL=${OBOS_RPI_ROOT_PARTITION_LABEL}" "${CMDLINE_TXT}"
check_cmdline_token "rootfstype=ext4" "${CMDLINE_TXT}"
check_cmdline_token "fsck.repair=yes" "${CMDLINE_TXT}"
check_cmdline_token "rootwait" "${CMDLINE_TXT}"
check_line "nvme" "${INITRAMFS_MODULES}"
check_line "nvme-core" "${INITRAMFS_MODULES}"
check_line "pcie-brcmstb" "${INITRAMFS_MODULES}"
check_line "xhci-pci" "${INITRAMFS_MODULES}"

echo "Raspberry Pi boot files: PASS ${ROOT_DIR}"
