#!/bin/sh
set -eu

DEBCONF_MODULE="${OBOS_INSTALLER_DEBCONF_MODULE:-/usr/share/debconf/confmodule}"
INSTALLER_TEMPLATES="${OBOS_INSTALLER_TEMPLATES:-/usr/share/obos-installer/installer.templates}"
LIST_DEVICES="${OBOS_INSTALLER_LIST_DEVICES:-list-devices}"
SYS_BLOCK_DIR="${OBOS_INSTALLER_SYS_BLOCK_DIR:-/sys/class/block}"
PROC_MOUNTS="${OBOS_INSTALLER_PROC_MOUNTS:-/proc/mounts}"

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

db_set partman-auto/disk "${target_disk}"

