#!/usr/bin/env sh
set -eu

fail() {
  echo "image profile validation failed: $1" >&2
  exit 1
}

contains_csv_value() {
  values="$1"
  expected="$2"
  case ",${values}," in
    *,${expected},*) return 0 ;;
    *) return 1 ;;
  esac
}

validate_profile() {
  profile_file="$1"
  [ -f "${profile_file}" ] || fail "missing profile: ${profile_file}"

  OBOS_IMAGE_PROFILE=
  OBOS_IMAGE_ARCH=
  OBOS_IMAGE_KIND=
  OBOS_DEBIAN_RELEASE=
  OBOS_DEBIAN_COMPONENTS=
  OBOS_BOOT_TARGET=
  OBOS_OUTPUT_FORMAT=
  OBOS_OUTPUT_COMPRESSION=
  OBOS_IMAGE_EXTENSION=
  OBOS_IMAGE_MIN_SIZE=
  OBOS_BASE_PACKAGES=
  OBOS_RPI_BOOT_PACKAGES=
  OBOS_PROVISION_SCRIPT=
  OBOS_FIRST_BOOT_SERVICE=
  OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE=
  OBOS_RPI_BOOT_MEDIA=
  OBOS_RPI_FIRMWARE_MODE=
  OBOS_RPI_PARTITION_LAYOUT=
  OBOS_RPI_BOOT_PARTITION_LABEL=
  OBOS_RPI_ROOT_PARTITION_LABEL=
  OBOS_RPI_REQUIRED_TOOLS=
  OBOS_KERNEL_REQUIRED_CONFIG=
  OBOS_QCOW2_BASE_IMAGE_URL=
  OBOS_QCOW2_MIN_SIZE=
  OBOS_QCOW2_BUILDER=
  OBOS_QCOW2_REQUIRED_TOOLS=
  OBOS_IMAGE_DEFAULT_SSH=

  # shellcheck disable=SC1090
  . "${profile_file}"

  [ -n "${OBOS_IMAGE_PROFILE}" ] || fail "${profile_file}: OBOS_IMAGE_PROFILE missing"
  [ -n "${OBOS_IMAGE_ARCH}" ] || fail "${profile_file}: OBOS_IMAGE_ARCH missing"
  [ -n "${OBOS_IMAGE_KIND}" ] || fail "${profile_file}: OBOS_IMAGE_KIND missing"
  [ -n "${OBOS_DEBIAN_RELEASE}" ] || fail "${profile_file}: OBOS_DEBIAN_RELEASE missing"
  [ -n "${OBOS_BOOT_TARGET}" ] || fail "${profile_file}: OBOS_BOOT_TARGET missing"
  [ -n "${OBOS_OUTPUT_FORMAT}" ] || fail "${profile_file}: OBOS_OUTPUT_FORMAT missing"
  [ -n "${OBOS_BASE_PACKAGES}" ] || fail "${profile_file}: OBOS_BASE_PACKAGES missing"
  [ -n "${OBOS_PROVISION_SCRIPT}" ] || fail "${profile_file}: OBOS_PROVISION_SCRIPT missing"
  [ -n "${OBOS_FIRST_BOOT_SERVICE}" ] || fail "${profile_file}: OBOS_FIRST_BOOT_SERVICE missing"

  case "${OBOS_IMAGE_ARCH}" in
    amd64|arm64) ;;
    *) fail "${profile_file}: unsupported architecture ${OBOS_IMAGE_ARCH}" ;;
  esac

  case "${OBOS_IMAGE_KIND}" in
    vm-image|installer-iso|rpi-image) ;;
    *) fail "${profile_file}: unsupported image kind ${OBOS_IMAGE_KIND}" ;;
  esac

  case "${OBOS_DEBIAN_RELEASE}" in
    trixie) ;;
    *) fail "${profile_file}: unsupported Debian release ${OBOS_DEBIAN_RELEASE}" ;;
  esac

  case "${OBOS_OUTPUT_FORMAT}" in
    qcow2|raw|iso) ;;
    *) fail "${profile_file}: unsupported output format ${OBOS_OUTPUT_FORMAT}" ;;
  esac

  [ "${OBOS_PROVISION_SCRIPT}" = "scripts/bootstrap/provision-debian.sh" ] \
    || fail "${profile_file}: image profile must use the shared Debian provisioner"
  [ "${OBOS_FIRST_BOOT_SERVICE}" = "obos-first-boot.service" ] \
    || fail "${profile_file}: first boot service must remain obos-first-boot.service"

  if [ "${OBOS_OUTPUT_FORMAT}" = "qcow2" ]; then
    [ -n "${OBOS_QCOW2_BASE_IMAGE_URL}" ] \
      || fail "${profile_file}: qcow2 profile must define OBOS_QCOW2_BASE_IMAGE_URL"
    [ -n "${OBOS_QCOW2_MIN_SIZE}" ] \
      || fail "${profile_file}: qcow2 profile must define OBOS_QCOW2_MIN_SIZE"
    [ "${OBOS_QCOW2_BUILDER}" = "virt-customize" ] \
      || fail "${profile_file}: qcow2 profile must use virt-customize builder"
    contains_csv_value "${OBOS_QCOW2_REQUIRED_TOOLS}" qemu-img \
      || fail "${profile_file}: qcow2 required tools must include qemu-img"
    contains_csv_value "${OBOS_QCOW2_REQUIRED_TOOLS}" virt-customize \
      || fail "${profile_file}: qcow2 required tools must include virt-customize"
    contains_csv_value "${OBOS_QCOW2_REQUIRED_TOOLS}" virt-sysprep \
      || fail "${profile_file}: qcow2 required tools must include virt-sysprep"
    [ "${OBOS_IMAGE_DEFAULT_SSH}" = "disabled" ] \
      || fail "${profile_file}: qcow2 image default SSH policy must be disabled"
  fi

  if [ "${OBOS_IMAGE_KIND}" = "rpi-image" ]; then
    [ "${OBOS_IMAGE_ARCH}" = "arm64" ] \
      || fail "${profile_file}: Raspberry Pi images must be arm64"
    [ "${OBOS_OUTPUT_FORMAT}" = "raw" ] \
      || fail "${profile_file}: Raspberry Pi images must use raw output before compression"
    [ "${OBOS_OUTPUT_COMPRESSION}" = "xz" ] \
      || fail "${profile_file}: Raspberry Pi images must use xz compression"
    [ "${OBOS_IMAGE_EXTENSION}" = "img.xz" ] \
      || fail "${profile_file}: Raspberry Pi artifact extension must be img.xz"
    [ -n "${OBOS_IMAGE_MIN_SIZE}" ] \
      || fail "${profile_file}: Raspberry Pi image minimum size must be defined"
    contains_csv_value "${OBOS_DEBIAN_COMPONENTS}" main \
      || fail "${profile_file}: Raspberry Pi Debian components must include main"
    contains_csv_value "${OBOS_DEBIAN_COMPONENTS}" non-free-firmware \
      || fail "${profile_file}: Raspberry Pi Debian components must include non-free-firmware"
    contains_csv_value "${OBOS_RPI_BOOT_PACKAGES}" linux-image-arm64 \
      || fail "${profile_file}: Raspberry Pi boot packages must include linux-image-arm64"
    contains_csv_value "${OBOS_RPI_BOOT_PACKAGES}" raspi-firmware \
      || fail "${profile_file}: Raspberry Pi boot packages must include raspi-firmware"
    contains_csv_value "${OBOS_RPI_BOOT_PACKAGES}" initramfs-tools \
      || fail "${profile_file}: Raspberry Pi boot packages must include initramfs-tools"
    [ "${OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE}" = "true" ] \
      || fail "${profile_file}: Raspberry Pi Network Installer compatibility must be explicit"
    [ "${OBOS_RPI_FIRMWARE_MODE}" = "raspberry-pi-bootloader" ] \
      || fail "${profile_file}: Raspberry Pi firmware mode must use the Raspberry Pi bootloader"
    contains_csv_value "${OBOS_RPI_BOOT_MEDIA}" sd \
      || fail "${profile_file}: Raspberry Pi boot media must include SD"
    contains_csv_value "${OBOS_RPI_BOOT_MEDIA}" usb \
      || fail "${profile_file}: Raspberry Pi boot media must include USB"
    contains_csv_value "${OBOS_RPI_BOOT_MEDIA}" nvme \
      || fail "${profile_file}: Raspberry Pi boot media must include NVMe"
    contains_csv_value "${OBOS_RPI_PARTITION_LAYOUT}" boot-fat32 \
      || fail "${profile_file}: Raspberry Pi partition layout must include boot-fat32"
    contains_csv_value "${OBOS_RPI_PARTITION_LAYOUT}" root-ext4 \
      || fail "${profile_file}: Raspberry Pi partition layout must include root-ext4"
    [ -n "${OBOS_RPI_BOOT_PARTITION_LABEL}" ] \
      || fail "${profile_file}: Raspberry Pi boot partition label must be defined"
    [ -n "${OBOS_RPI_ROOT_PARTITION_LABEL}" ] \
      || fail "${profile_file}: Raspberry Pi root partition label must be defined"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" debootstrap \
      || fail "${profile_file}: Raspberry Pi required tools must include debootstrap"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" qemu-aarch64-static \
      || fail "${profile_file}: Raspberry Pi required tools must include qemu-aarch64-static"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" sfdisk \
      || fail "${profile_file}: Raspberry Pi required tools must include sfdisk"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" mkfs.vfat \
      || fail "${profile_file}: Raspberry Pi required tools must include mkfs.vfat"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" mkfs.ext4 \
      || fail "${profile_file}: Raspberry Pi required tools must include mkfs.ext4"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" losetup \
      || fail "${profile_file}: Raspberry Pi required tools must include losetup"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" mount \
      || fail "${profile_file}: Raspberry Pi required tools must include mount"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" umount \
      || fail "${profile_file}: Raspberry Pi required tools must include umount"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" partprobe \
      || fail "${profile_file}: Raspberry Pi required tools must include partprobe"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" tar \
      || fail "${profile_file}: Raspberry Pi required tools must include tar"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" xz \
      || fail "${profile_file}: Raspberry Pi required tools must include xz"
    contains_csv_value "${OBOS_RPI_REQUIRED_TOOLS}" sha256sum \
      || fail "${profile_file}: Raspberry Pi required tools must include sha256sum"
    contains_csv_value "${OBOS_KERNEL_REQUIRED_CONFIG}" 'CONFIG_BLK_DEV_NVME=y' \
      || fail "${profile_file}: Raspberry Pi kernel config must enable CONFIG_BLK_DEV_NVME=y"
    contains_csv_value "${OBOS_KERNEL_REQUIRED_CONFIG}" 'CONFIG_PCIE_BRCMSTB=y' \
      || fail "${profile_file}: Raspberry Pi kernel config must enable CONFIG_PCIE_BRCMSTB=y"
    contains_csv_value "${OBOS_KERNEL_REQUIRED_CONFIG}" 'CONFIG_USB_XHCI_PCI=y' \
      || fail "${profile_file}: Raspberry Pi kernel config must enable CONFIG_USB_XHCI_PCI=y"
    [ "${OBOS_IMAGE_DEFAULT_SSH}" = "disabled" ] \
      || fail "${profile_file}: Raspberry Pi image default SSH policy must be disabled"
  fi

  echo "PASS ${profile_file}"
}

if [ "$#" -eq 0 ]; then
  set -- packaging/images/profiles/*.env
fi

for profile in "$@"; do
  validate_profile "${profile}"
done
