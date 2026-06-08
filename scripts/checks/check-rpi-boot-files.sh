#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

GOOD_ROOT="${TMP_DIR}/good-root"
BAD_ROOT="${TMP_DIR}/bad-root"

mkdir -p "${GOOD_ROOT}/etc/initramfs-tools" "${GOOD_ROOT}/boot"

cat > "${GOOD_ROOT}/etc/fstab" <<EOF
LABEL=OBOSROOT / ext4 defaults,noatime 0 1
LABEL=OBOSBOOT /boot vfat defaults 0 2
EOF

cat > "${GOOD_ROOT}/boot/config.txt" <<EOF
arm_64bit=1
auto_initramfs=1
EOF

cat > "${GOOD_ROOT}/boot/cmdline.txt" <<EOF
console=serial0,115200 console=tty1 root=LABEL=OBOSROOT rootfstype=ext4 fsck.repair=yes rootwait quiet
EOF

cat > "${GOOD_ROOT}/etc/initramfs-tools/modules" <<EOF
nvme
nvme-core
pcie-brcmstb
xhci-pci
EOF

sh scripts/images/check-rpi-boot-files.sh "${GOOD_ROOT}" >/dev/null

cp -a "${GOOD_ROOT}" "${BAD_ROOT}"
sed 's/rootwait//' "${GOOD_ROOT}/boot/cmdline.txt" > "${BAD_ROOT}/boot/cmdline.txt"

if sh scripts/images/check-rpi-boot-files.sh "${BAD_ROOT}" >/dev/null 2>&1; then
  echo "Raspberry Pi boot files fixture failed: missing rootwait was accepted" >&2
  exit 1
fi

cp -a "${GOOD_ROOT}" "${BAD_ROOT}"
sed 's/root=LABEL=OBOSROOT/root=LABEL=WRONGROOT/' "${GOOD_ROOT}/boot/cmdline.txt" > "${BAD_ROOT}/boot/cmdline.txt"

if sh scripts/images/check-rpi-boot-files.sh "${BAD_ROOT}" >/dev/null 2>&1; then
  echo "Raspberry Pi boot files fixture failed: wrong root label was accepted" >&2
  exit 1
fi

cp -a "${GOOD_ROOT}" "${BAD_ROOT}"
sed '/^arm_64bit=1$/d' "${GOOD_ROOT}/boot/config.txt" > "${BAD_ROOT}/boot/config.txt"

if sh scripts/images/check-rpi-boot-files.sh "${BAD_ROOT}" >/dev/null 2>&1; then
  echo "Raspberry Pi boot files fixture failed: missing 64-bit boot mode was accepted" >&2
  exit 1
fi

cp -a "${GOOD_ROOT}" "${BAD_ROOT}"
sed '/^nvme$/d' "${GOOD_ROOT}/etc/initramfs-tools/modules" > "${BAD_ROOT}/etc/initramfs-tools/modules"

if sh scripts/images/check-rpi-boot-files.sh "${BAD_ROOT}" >/dev/null 2>&1; then
  echo "Raspberry Pi boot files fixture failed: missing NVMe initramfs module was accepted" >&2
  exit 1
fi

echo "Raspberry Pi boot files fixture: PASS"
