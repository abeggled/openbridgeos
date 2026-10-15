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
db_fset() { printf 'fset:%s:%s:%s\n' "$1" "$2" "$3" >> "${OBOS_TEST_DB_LOG}"; }
db_input() { printf 'input:%s:%s\n' "$1" "$2" >> "${OBOS_TEST_DB_LOG}"; }
db_go() { :; }
db_get() { RET="${OBOS_TEST_CONFIRM:-true}"; }
db_set() { printf 'set:%s:%s\n' "$1" "$2" >> "${OBOS_TEST_DB_LOG}"; }
db_unregister() { :; }
EOF
cat > "${TMP_DIR}/bin/debconf-loadtemplate" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "${TMP_DIR}/bin/list-devices" <<EOF
#!/bin/sh
case "\${1:-}" in
  disk) cat "${TMP_DIR}/disks" ;;
  partition) cat "${TMP_DIR}/partitions" ;;
  *) exit 2 ;;
esac
EOF
cat > "${TMP_DIR}/bin/dd" <<'EOF'
#!/bin/sh
printf 'dd:%s\n' "$*" >> "${OBOS_TEST_DISK_LOG}"
EOF
cat > "${TMP_DIR}/bin/blockdev" <<'EOF'
#!/bin/sh
printf 'blockdev:%s\n' "$*" >> "${OBOS_TEST_DISK_LOG}"
EOF
cat > "${TMP_DIR}/bin/udevadm" <<'EOF'
#!/bin/sh
printf 'udevadm:%s\n' "$*" >> "${OBOS_TEST_DISK_LOG}"
EOF
chmod 0755 "${TMP_DIR}/bin/debconf-loadtemplate" "${TMP_DIR}/bin/list-devices" \
  "${TMP_DIR}/bin/dd" "${TMP_DIR}/bin/blockdev" "${TMP_DIR}/bin/udevadm"
printf '/dev/sdz1 /cdrom iso9660 ro 0 0\n' > "${TMP_DIR}/mounts"
printf '0\n' > "${TMP_DIR}/sys/sda/removable"
printf '83886080\n' > "${TMP_DIR}/sys/sda/size"
printf 'Fixture Disk A\n' > "${TMP_DIR}/sys/sda/device/model"
printf '0\n' > "${TMP_DIR}/sys/sdb/removable"
printf '125829120\n' > "${TMP_DIR}/sys/sdb/size"
printf 'Fixture Disk B\n' > "${TMP_DIR}/sys/sdb/device/model"
printf '/dev/sda\n' > "${TMP_DIR}/disks"
printf '/dev/sda1\n/dev/sda2\n' > "${TMP_DIR}/partitions"
: > "${TMP_DIR}/db.log"
: > "${TMP_DIR}/disk.log"

PATH="${TMP_DIR}/bin:${PATH}" \
OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
OBOS_INSTALLER_LIST_DEVICES="${TMP_DIR}/bin/list-devices" \
OBOS_INSTALLER_SYS_BLOCK_DIR="${TMP_DIR}/sys" \
OBOS_INSTALLER_PROC_MOUNTS="${TMP_DIR}/mounts" \
OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
OBOS_TEST_DISK_LOG="${TMP_DIR}/disk.log" \
sh "${INSTALLER_DIR}/select-target-disk.sh"

grep -Fq 'set:partman-auto/disk:/dev/sda' "${TMP_DIR}/db.log" \
  || fail "single eligible disk was not selected"
grep -Fq 'set:grub-installer/bootdev:/dev/sda' "${TMP_DIR}/db.log" \
  || fail "GRUB was not assigned to the selected whole disk"
grep -Fq 'fset:grub-installer/bootdev:seen:true' "${TMP_DIR}/db.log" \
  || fail "GRUB whole-disk answer was not marked as already handled"
grep -Fq 'input:critical:obos-installer/confirm-single-disk' "${TMP_DIR}/db.log" \
  || fail "single-disk destructive warning was not shown"
grep -Fq 'of=/dev/sda1 ' "${TMP_DIR}/disk.log" \
  || fail "first existing target partition was not erased"
grep -Fq 'of=/dev/sda2 ' "${TMP_DIR}/disk.log" \
  || fail "second existing target partition was not erased"
[ "$(grep -Fc 'of=/dev/sda ' "${TMP_DIR}/disk.log")" -eq 2 ] \
  || fail "both partition-table locations on the selected disk were not erased"
grep -Fq 'blockdev:--rereadpt /dev/sda' "${TMP_DIR}/disk.log" \
  || fail "kernel partition table was not refreshed after disk cleanup"
grep -Fq 'udevadm:settle' "${TMP_DIR}/disk.log" \
  || fail "device events were not settled after disk cleanup"

printf '/dev/sda\n' > "${TMP_DIR}/disks"
: > "${TMP_DIR}/db.log"
: > "${TMP_DIR}/disk.log"
if PATH="${TMP_DIR}/bin:${PATH}" \
  OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
  OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
  OBOS_INSTALLER_LIST_DEVICES="${TMP_DIR}/bin/list-devices" \
  OBOS_INSTALLER_SYS_BLOCK_DIR="${TMP_DIR}/sys" \
  OBOS_INSTALLER_PROC_MOUNTS="${TMP_DIR}/mounts" \
  OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
  OBOS_TEST_DISK_LOG="${TMP_DIR}/disk.log" \
  OBOS_TEST_CONFIRM=false \
  sh "${INSTALLER_DIR}/select-target-disk.sh"; then
  fail "rejected destructive confirmation did not stop installation"
fi
[ ! -s "${TMP_DIR}/disk.log" ] \
  || fail "rejected destructive confirmation attempted disk cleanup"

printf '/dev/sda\n/dev/sdb\n' > "${TMP_DIR}/disks"
: > "${TMP_DIR}/db.log"
: > "${TMP_DIR}/disk.log"
if PATH="${TMP_DIR}/bin:${PATH}" \
  OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
  OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
  OBOS_INSTALLER_LIST_DEVICES="${TMP_DIR}/bin/list-devices" \
  OBOS_INSTALLER_SYS_BLOCK_DIR="${TMP_DIR}/sys" \
  OBOS_INSTALLER_PROC_MOUNTS="${TMP_DIR}/mounts" \
  OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
  OBOS_TEST_DISK_LOG="${TMP_DIR}/disk.log" \
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
[ ! -s "${TMP_DIR}/disk.log" ] \
  || fail "multiple-disk fail-closed path attempted destructive cleanup"

grep -Fq 'passwd/root-password-crypted password !' "${INSTALLER_DIR}/preseed.cfg" \
  || fail "root password questions are not suppressed securely"
grep -Fq 'passwd/user-password-crypted password !' "${INSTALLER_DIR}/preseed.cfg" \
  || fail "regular-user password questions are not suppressed securely"
grep -Fq 'clock-setup/ntp-server string pool.ntp.org' "${INSTALLER_DIR}/preseed.cfg" \
  || fail "installer NTP server is not preconfigured"
grep -Fq 'grub-installer/bootdev string default' "${INSTALLER_DIR}/preseed.cfg" \
  || fail "GRUB has no preseeded fallback boot disk"
grep -Fq 'base-installer/use_unclean_target boolean true' "${INSTALLER_DIR}/preseed.cfg" \
  || fail "partial base-system installation retry can still stop interactively"

mkdir -p "${TMP_DIR}/target/etc/obos"
printf '%s\n' 'obos_password=FixtureRecoveryPassword_123' > "${TMP_DIR}/target/etc/obos/system-credentials"
cat > "${TMP_DIR}/bin/in-target" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "${TMP_DIR}/bin/ip" <<'EOF'
#!/bin/sh
printf '%s\n' '2: ens18    inet 10.38.114.103/24 brd 10.38.114.255 scope global dynamic ens18'
EOF
chmod 0755 "${TMP_DIR}/bin/in-target" "${TMP_DIR}/bin/ip"
: > "${TMP_DIR}/db.log"
PATH="${TMP_DIR}/bin:${PATH}" \
OBOS_INSTALLER_DEBCONF_MODULE="${TMP_DIR}/confmodule" \
OBOS_INSTALLER_TEMPLATES="${INSTALLER_DIR}/installer.templates" \
OBOS_INSTALLER_TARGET_ROOT="${TMP_DIR}/target" \
OBOS_INSTALLER_IN_TARGET="${TMP_DIR}/bin/in-target" \
OBOS_INSTALLER_IP_COMMAND="${TMP_DIR}/bin/ip" \
OBOS_TEST_DB_LOG="${TMP_DIR}/db.log" \
sh "${INSTALLER_DIR}/finalize.sh"
grep -Fq 'subst:obos-installer/recovery-password:IP_ADDRESS:10.38.114.103' "${TMP_DIR}/db.log" \
  || fail "completion screen does not include the DHCP IPv4 address"
grep -Fq 'subst:obos-installer/recovery-password:WEB_URL:https://10.38.114.103/obos/' "${TMP_DIR}/db.log" \
  || fail "completion screen does not include the web-console URL"

echo "appliance installer check: PASS"

