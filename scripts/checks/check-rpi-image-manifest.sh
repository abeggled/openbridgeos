#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

IMAGE_FILE="${TMP_DIR}/obos-rpi4-arm64-test.img.xz"
CHECKSUM_FILE="${IMAGE_FILE}.sha256"
MANIFEST_FILE="${TMP_DIR}/obos-rpi4-arm64-test.img.xz.manifest"

printf 'test rpi image\n' > "${IMAGE_FILE}"
IMAGE_SHA256="$(sha256sum "${IMAGE_FILE}" | cut -d ' ' -f 1)"
sha256sum "${IMAGE_FILE}" > "${CHECKSUM_FILE}"

cat > "${MANIFEST_FILE}" <<EOF
format=obos-rpi-image-build-v1
created_at=20260604T000000Z
profile=rpi4-arm64
architecture=arm64
debian_release=trixie
output_format=raw
output_compression=xz
image_extension=img.xz
release_build=1
image=${IMAGE_FILE}
checksum_file=${CHECKSUM_FILE}
image_sha256=${IMAGE_SHA256}
network_installer_compatible=true
boot_media=sd,usb,nvme
firmware_mode=raspberry-pi-bootloader
partition_layout=boot-fat32,root-ext4
boot_partition_label=OBOSBOOT
root_partition_label=OBOSROOT
kernel_required_config=CONFIG_BLK_DEV_NVME=y,CONFIG_PCIE_BRCMSTB=y,CONFIG_USB_XHCI_PCI=y
kernel_config_verified=true
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=test-revision
repo_dirty=false
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF

OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-rpi-image-manifest.sh "${MANIFEST_FILE}" >/dev/null

DIRTY_MANIFEST="${TMP_DIR}/obos-rpi4-arm64-test-dirty.img.xz.manifest"
sed 's/^repo_dirty=false$/repo_dirty=true/' "${MANIFEST_FILE}" > "${DIRTY_MANIFEST}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-rpi-image-manifest.sh "${DIRTY_MANIFEST}" >/dev/null 2>&1; then
  echo "Raspberry Pi image manifest fixture failed: dirty release manifest was accepted" >&2
  exit 1
fi

WRONG_PROVISIONER_MANIFEST="${TMP_DIR}/obos-rpi4-arm64-test-wrong-provisioner.img.xz.manifest"
sed 's|^provision_script=scripts/bootstrap/provision-debian.sh$|provision_script=scripts/bootstrap/other.sh|' "${MANIFEST_FILE}" > "${WRONG_PROVISIONER_MANIFEST}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-rpi-image-manifest.sh "${WRONG_PROVISIONER_MANIFEST}" >/dev/null 2>&1; then
  echo "Raspberry Pi image manifest fixture failed: wrong provisioner manifest was accepted" >&2
  exit 1
fi

printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "${IMAGE_FILE}" > "${CHECKSUM_FILE}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-rpi-image-manifest.sh "${MANIFEST_FILE}" >/dev/null 2>&1; then
  echo "Raspberry Pi image manifest fixture failed: checksum file mismatch was accepted" >&2
  exit 1
fi

echo "Raspberry Pi image manifest fixture: PASS"
