#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CONFIG_FILE="${TMP_DIR}/config-6.1.0-rpi-arm64"

cat > "${CONFIG_FILE}" <<EOF
CONFIG_BLK_DEV_NVME=y
CONFIG_PCIE_BRCMSTB=y
CONFIG_USB_XHCI_PCI=y
EOF

sh scripts/images/check-rpi-kernel-config.sh "${CONFIG_FILE}" >/dev/null

ROOT_DIR="${TMP_DIR}/root"
mkdir -p "${ROOT_DIR}/boot"
cat > "${ROOT_DIR}/boot/config.txt" <<EOF
arm_64bit=1
auto_initramfs=1
EOF
cp "${CONFIG_FILE}" "${ROOT_DIR}/boot/config-6.1.0-rpi-arm64"

sh scripts/images/check-rpi-kernel-config.sh "${ROOT_DIR}" >/dev/null

echo "Raspberry Pi kernel config fixture: PASS"
