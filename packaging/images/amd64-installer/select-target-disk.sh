#!/bin/sh
set -eu

DEBCONF_MODULE="${OBOS_INSTALLER_DEBCONF_MODULE:-/usr/share/debconf/confmodule}"
INSTALLER_TEMPLATES="${OBOS_INSTALLER_TEMPLATES:-/usr/share/obos-installer/installer.templates}"
LIST_DEVICES="${OBOS_INSTALLER_LIST_DEVICES:-list-devices}"
SYS_BLOCK_DIR="${OBOS_INSTALLER_SYS_BLOCK_DIR:-/sys/class/block}"
PROC_MOUNTS="${OBOS_INSTALLER_PROC_MOUNTS:-/proc/mounts}"
DD_COMMAND="${OBOS_INSTALLER_DD_COMMAND:-dd}"
BLOCKDEV_COMMAND="${OBOS_INSTALLER_BLOCKDEV_COMMAND:-blockdev}"
UDEVADM_COMMAND="${OBOS_INSTALLER_UDEVADM_COMMAND:-udevadm}"

# shellcheck disable=SC1090
. "${DEBCONF_MODULE}"
debconf-loadtemplate obos-installer "${INSTALLER_TEMPLATES}"

media_source="$(awk '$2 == "/cdrom" { print $1; exit }' "${PROC_MOUNTS}")"
eligible_disks=
eligible_count=0

# Fail closed even if the installer ignores a non-zero early-command exit.
db_set partman-auto/disk /dev/obos-no-safe-target

for disk in $("${LIST_DEVICES}" disk); do
  case "${disk}" in
    /dev/loop*|/dev/ram*|/dev/sr*|/dev/fd*) continue ;;
  esac
  case "${media_source}" in
    "${disk}"|"${disk}"[0-9]*|"${disk}"p[0-9]*) continue ;;
  esac
  device_name="${disk#/dev/}"
  removable="$(cat "${SYS_BLOCK_DIR}/${device_name}/removable" 2>/dev/null || printf '1')"
  [ "${removable}" = 0 ] || continue
  sectors="$(cat "${SYS_BLOCK_DIR}/${device_name}/size" 2>/dev/null || printf '0')"
  case "${sectors}" in ''|*[!0-9]*) sectors=0 ;; esac
  size_bytes=$((sectors * 512))
  [ "${size_bytes}" -ge 8589934592 ] || continue
  eligible_disks="${eligible_disks} ${disk}"
  eligible_count=$((eligible_count + 1))
done

if [ "${eligible_count}" -ne 1 ]; then
  db_subst obos-installer/no-safe-target COUNT "${eligible_count}"
  db_fset obos-installer/no-safe-target seen false
  db_input critical obos-installer/no-safe-target || true
  db_go
  exit 1
fi

target_disk="${eligible_disks# }"
device_name="${target_disk#/dev/}"
model="$(tr -d '\n\r' < "${SYS_BLOCK_DIR}/${device_name}/device/model" 2>/dev/null || printf 'unknown')"
[ -n "${model}" ] || model=unknown
sectors="$(cat "${SYS_BLOCK_DIR}/${device_name}/size")"
size_gib="$(awk -v sectors="${sectors}" 'BEGIN { printf "%.1f GiB", sectors * 512 / 1073741824 }')"

db_subst obos-installer/confirm-single-disk DISK "${target_disk}"
db_subst obos-installer/confirm-single-disk MODEL "${model}"
db_subst obos-installer/confirm-single-disk SIZE "${size_gib}"
db_fset obos-installer/confirm-single-disk seen false
db_input critical obos-installer/confirm-single-disk || true
db_go
db_get obos-installer/confirm-single-disk
[ "${RET}" = true ] || exit 1

# Remove filesystems and both copies of a GPT partition table only after the
# operator has confirmed the exact whole disk. This prevents partman/live-
# installer from reusing an old root filesystem and presenting the hidden
# base-installer/use_unclean_target question at critical priority.
for partition in $("${LIST_DEVICES}" partition); do
  case "${partition}" in
    "${target_disk}"[0-9]*|"${target_disk}"p[0-9]*)
      "${DD_COMMAND}" if=/dev/zero of="${partition}" bs=512 count=32768 >/dev/null 2>&1
      ;;
  esac
done
"${DD_COMMAND}" if=/dev/zero of="${target_disk}" bs=512 count=32768 >/dev/null 2>&1
if [ "${sectors}" -gt 32768 ]; then
  "${DD_COMMAND}" if=/dev/zero of="${target_disk}" bs=512 \
    seek=$((sectors - 32768)) count=32768 >/dev/null 2>&1
fi
sync
if command -v "${BLOCKDEV_COMMAND}" >/dev/null 2>&1; then
  "${BLOCKDEV_COMMAND}" --rereadpt "${target_disk}" >/dev/null 2>&1 || true
fi
if command -v "${UDEVADM_COMMAND}" >/dev/null 2>&1; then
  "${UDEVADM_COMMAND}" settle >/dev/null 2>&1 || true
fi

db_set partman-auto/disk "${target_disk}"
db_set grub-installer/bootdev "${target_disk}"
db_fset grub-installer/bootdev seen true

