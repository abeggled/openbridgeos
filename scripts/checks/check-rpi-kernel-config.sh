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

echo "Raspberry Pi kernel config fixture: PASS"
