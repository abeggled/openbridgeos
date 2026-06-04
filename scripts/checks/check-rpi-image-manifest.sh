#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

IMAGE_FILE="${TMP_DIR}/obos-rpi4-arm64-test.img.xz"
MANIFEST_FILE="${TMP_DIR}/obos-rpi4-arm64-test.img.xz.manifest"

printf 'test rpi image\n' > "${IMAGE_FILE}"
IMAGE_SHA256="$(sha256sum "${IMAGE_FILE}" | cut -d ' ' -f 1)"

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
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF

OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-rpi-image-manifest.sh "${MANIFEST_FILE}" >/dev/null

echo "Raspberry Pi image manifest fixture: PASS"
