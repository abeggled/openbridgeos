#!/usr/bin/env sh
set -eu

INSTALLER_DIR="packaging/images/amd64-installer"
BUILDER="scripts/images/build-amd64-installer-iso.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  echo "appliance installer check failed: $1" >&2
  exit 1
}

for required_file in \
  preseed.cfg installer.templates select-target-disk.sh finalize.sh \
  bootloaders/isolinux/isolinux.cfg \
  bootloaders/syslinux_common/menu.cfg \
  bootloaders/syslinux_common/install_gui.cfg \
  bootloaders/grub-pc/config.cfg \
  bootloaders/grub-pc/grub.cfg \
  bootloaders/grub-pc/install_start_gui.cfg; do
  [ -s "${INSTALLER_DIR}/${required_file}" ] || fail "missing ${required_file}"
done

grep -Fq 'default installstart' "${INSTALLER_DIR}/bootloaders/isolinux/isolinux.cfg" \
  || fail "BIOS boot does not default to Start installer"
grep -Fq 'set timeout=5' "${INSTALLER_DIR}/bootloaders/grub-pc/config.cfg" \
  || fail "UEFI boot does not use the short installer timeout"
if grep -Fq '@LINUX_LIVE@' "${INSTALLER_DIR}/bootloaders/grub-pc/grub.cfg"; then
  fail "UEFI boot menu still starts with the live system"
fi
if grep -Fq 'include live.cfg' "${INSTALLER_DIR}/bootloaders/syslinux_common/menu.cfg"; then
  fail "BIOS boot menu still starts with the live system"
fi
grep -Fq 'auto=true priority=critical file=/cdrom/install/preseed.cfg' \
  "${INSTALLER_DIR}/bootloaders/grub-pc/install_start_gui.cfg" \
  || fail "UEFI Start installer is not automated"
grep -Fq 'auto=true priority=critical file=/cdrom/install/preseed.cfg' \
  "${INSTALLER_DIR}/bootloaders/syslinux_common/install_gui.cfg" \
  || fail "BIOS Start installer is not automated"
grep -Fq 'cp -a /usr/share/live/build/bootloaders/.' "${BUILDER}" \
  || fail "ISO builder does not install the appliance boot menu"
grep -Fq 'config/preseed/obos.cfg' "${BUILDER}" \
  || fail "ISO builder does not install the appliance preseed"

mkdir -p "${TMP_DIR}/bin" "${TMP_DIR}/sys/sda/device" "${TMP_DIR}/sys/sdb/device"
cat > "${TMP_DIR}/confmodule" <<'EOF'
db_subst() { printf 'subst:%s:%s:%s\n' "$1" "$2" "$3" >> "${OBOS_TEST_DB_LOG}"; }
db_fset() { :; }
db_input() { printf 'input:%s:%s\n' "$1" "$2" >> "${OBOS_TEST_DB_LOG}"; }
db_go() { :; }
db_get() { RET="${OBOS_TEST_CONFIRM:-true}"; }
db_set() { printf 'set:%s:%s\n' "$1" "$2" >> "${OBOS_TEST_DB_LOG}"; }
EOF
cat > "${TMP_DIR}/bin/debconf-loadtemplate" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "${TMP_DIR}/bin/list-devices" <<EOF
#!/bin/sh
cat "${TMP_DIR}/disks"
EOF
chmod 0755 "${TMP_DIR}/bin/debconf-loadtemplate" "${TMP_DIR}/bin/list-devices"
printf '/dev/sdz1 /cdrom iso9660 ro 0 0\n' > "${TMP_DIR}/mounts"
printf '0\n' > "${TMP_DIR}/sys/sda/removable"
printf '83886080\n' > "${TMP_DIR}/sys/sda/size"
printf 'Fixture Disk A\n' > "${TMP_DIR}/sys/sda/device/model"
printf '0\n' > "${TMP_DIR}/sys/sdb/removable"
printf '125829120\n' > "${TMP_DIR}/sys/sdb/size"
printf 'Fixture Disk B\n' > "${TMP_DIR}/sys/sdb/device/model"
printf '/dev/sda\n' > "${TMP_DIR}/disks"
: > "${TMP_DIR}/db.log"

PATH="${TMP_DIR}/bin:${PATH}" \
OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
OBOS_INSTALLER_LIST_DEVICES="${TMP_DIR}/bin/list-devices" \
OBOS_INSTALLER_SYS_BLOCK_DIR="${TMP_DIR}/sys" \
OBOS_INSTALLER_PROC_MOUNTS="${TMP_DIR}/mounts" \
OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
sh "${INSTALLER_DIR}/select-target-disk.sh"

grep -Fq 'set:partman-auto/disk:/dev/sda' "${TMP_DIR}/db.log" \
  || fail "single eligible disk was not selected"
grep -Fq 'input:critical:obos-installer/confirm-single-disk' "${TMP_DIR}/db.log" \
  || fail "single-disk destructive warning was not shown"

printf '/dev/sda\n/dev/sdb\n' > "${TMP_DIR}/disks"
: > "${TMP_DIR}/db.log"
if PATH="${TMP_DIR}/bin:${PATH}" \
  OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
  OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
  OBOS_INSTALLER_LIST_DEVICES="${TMP_DIR}/bin/list-devices" \
  OBOS_INSTALLER_SYS_BLOCK_DIR="${TMP_DIR}/sys" \
  OBOS_INSTALLER_PROC_MOUNTS="${TMP_DIR}/mounts" \
  OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
  sh "${INSTALLER_DIR}/select-target-disk.sh"; then
  fail "multiple eligible disks did not stop automatic installation"
fi
if grep -Eq 'set:partman-auto/disk:/dev/(sda|sdb)' "${TMP_DIR}/db.log"; then
  fail "automatic installation selected a real disk from multiple candidates"
fi
grep -Fq 'set:partman-auto/disk:/dev/obos-no-safe-target' "${TMP_DIR}/db.log" \
  || fail "multiple-disk path did not retain the fail-closed disk guard"
grep -Fq 'input:critical:obos-installer/no-safe-target' "${TMP_DIR}/db.log" \
  || fail "multiple-disk stop message was not shown"

echo "appliance installer check: PASS"

