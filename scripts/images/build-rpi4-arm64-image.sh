#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/rpi4-arm64.env}"
WORK_DIR="${OBOS_IMAGE_WORK_DIR:-build/images/rpi4-arm64}"
OUTPUT_DIR="${OBOS_IMAGE_OUTPUT_DIR:-dist/images}"
REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
REPO_NAME="$(basename -- "${REPO_ROOT}")"
RELEASE_BUILD="${OBOS_RELEASE_BUILD:-0}"
VALIDATE_IMAGE_PROFILES="${REPO_ROOT}/scripts/images/validate-image-profiles.sh"
CHECK_RPI_BUILD_HOST="${REPO_ROOT}/scripts/images/check-rpi4-arm64-build-host.sh"
CHECK_RPI_KERNEL_CONFIG="${REPO_ROOT}/scripts/images/check-rpi-kernel-config.sh"
CHECK_RPI_BOOT_FILES="${REPO_ROOT}/scripts/images/check-rpi-boot-files.sh"
CHECK_RPI_MANIFEST="${REPO_ROOT}/scripts/images/check-rpi-image-manifest.sh"

LOOP_DEVICE=
BOOT_MOUNT=
ROOT_MOUNT=
BUILD_ROOT=

fail() {
  echo "Raspberry Pi arm64 image build failed: $1" >&2
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || fail "image build must run as root"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

run_build_host_preflight() {
  case "${PROFILE_FILE}" in
    /*) profile_arg="${PROFILE_FILE}" ;;
    *) profile_arg="$(pwd)/${PROFILE_FILE}" ;;
  esac

  (cd "${REPO_ROOT}" && OBOS_IMAGE_PROFILE_FILE="${profile_arg}" sh "${CHECK_RPI_BUILD_HOST}")
}

repo_revision() {
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse HEAD
  else
    echo unknown
  fi
}

repo_dirty() {
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    status="$(git -C "${REPO_ROOT}" status --porcelain)"
    if [ -n "${status}" ]; then
      echo true
    else
      echo false
    fi
  else
    echo unknown
  fi
}

require_clean_release_repo() {
  dirty="$(repo_dirty)"
  [ "${dirty}" = "false" ] || fail "release builds require a clean git tree, got repo_dirty=${dirty}"
}

cleanup() {
  if [ -n "${BOOT_MOUNT}" ] && mountpoint -q "${BOOT_MOUNT}"; then
    umount "${BOOT_MOUNT}" || true
  fi
  if [ -n "${BUILD_ROOT}" ] && mountpoint -q "${BUILD_ROOT}/proc"; then
    umount "${BUILD_ROOT}/proc" || true
  fi
  if [ -n "${BUILD_ROOT}" ] && mountpoint -q "${BUILD_ROOT}/sys"; then
    umount "${BUILD_ROOT}/sys" || true
  fi
  if [ -n "${BUILD_ROOT}" ] && mountpoint -q "${BUILD_ROOT}/dev"; then
    umount "${BUILD_ROOT}/dev" || true
  fi
  if [ -n "${ROOT_MOUNT}" ] && mountpoint -q "${ROOT_MOUNT}"; then
    umount "${ROOT_MOUNT}" || true
  fi
  if [ -n "${LOOP_DEVICE}" ]; then
    losetup -d "${LOOP_DEVICE}" || true
  fi
}

copy_repo_into_root() {
  root_dir="$1"
  image_repo_dir="${root_dir}/opt/openbridgeos/${REPO_NAME}"

  mkdir -p "${image_repo_dir}"
  tar -C "${REPO_ROOT}" \
    --exclude ./.git \
    --exclude ./build \
    --exclude ./dist \
    -cf - . | tar -C "${image_repo_dir}" -xf -
}

write_fstab() {
  root_dir="$1"

  cat > "${root_dir}/etc/fstab" <<EOF
LABEL=${OBOS_RPI_ROOT_PARTITION_LABEL} / ext4 defaults,noatime 0 1
LABEL=${OBOS_RPI_BOOT_PARTITION_LABEL} /boot vfat defaults 0 2
EOF
}

write_boot_config() {
  boot_dir="$1"

  cat > "${boot_dir}/config.txt" <<EOF
arm_64bit=1
auto_initramfs=1
EOF

  cat > "${boot_dir}/cmdline.txt" <<EOF
console=serial0,115200 console=tty1 root=LABEL=${OBOS_RPI_ROOT_PARTITION_LABEL} rootfstype=ext4 fsck.repair=yes rootwait quiet
EOF
}

write_manifest() {
  manifest_file="$1"
  image_file="$2"
  checksum_file="$3"
  created_at="$4"

  image_sha256="$(cut -d ' ' -f 1 < "${checksum_file}")"
  revision="$(repo_revision)"

  cat > "${manifest_file}" <<EOF
format=obos-rpi-image-build-v1
created_at=${created_at}
profile=${OBOS_IMAGE_PROFILE}
architecture=${OBOS_IMAGE_ARCH}
debian_release=${OBOS_DEBIAN_RELEASE}
output_format=${OBOS_OUTPUT_FORMAT}
output_compression=${OBOS_OUTPUT_COMPRESSION}
image_extension=${OBOS_IMAGE_EXTENSION}
release_build=${RELEASE_BUILD}
image=${image_file}
checksum_file=${checksum_file}
image_sha256=${image_sha256}
network_installer_compatible=${OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE}
boot_media=${OBOS_RPI_BOOT_MEDIA}
firmware_mode=${OBOS_RPI_FIRMWARE_MODE}
partition_layout=${OBOS_RPI_PARTITION_LAYOUT}
boot_partition_label=${OBOS_RPI_BOOT_PARTITION_LABEL}
root_partition_label=${OBOS_RPI_ROOT_PARTITION_LABEL}
kernel_required_config=${OBOS_KERNEL_REQUIRED_CONFIG}
kernel_config_verified=true
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
repo_revision=${revision}
repo_dirty=$(repo_dirty)
ssh_default=${OBOS_IMAGE_DEFAULT_SSH}
first_boot_pending=true
contains_secrets=false
EOF
}

require_root
[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"
[ -f "${VALIDATE_IMAGE_PROFILES}" ] || fail "missing image profile validator: ${VALIDATE_IMAGE_PROFILES}"
[ -f "${CHECK_RPI_BUILD_HOST}" ] || fail "missing build host preflight: ${CHECK_RPI_BUILD_HOST}"
[ -f "${CHECK_RPI_KERNEL_CONFIG}" ] || fail "missing kernel config checker: ${CHECK_RPI_KERNEL_CONFIG}"
[ -f "${CHECK_RPI_BOOT_FILES}" ] || fail "missing boot files checker: ${CHECK_RPI_BOOT_FILES}"
[ -f "${CHECK_RPI_MANIFEST}" ] || fail "missing manifest checker: ${CHECK_RPI_MANIFEST}"
run_build_host_preflight
sh "${VALIDATE_IMAGE_PROFILES}" "${PROFILE_FILE}" >/dev/null

case "${RELEASE_BUILD}" in
  0|1) ;;
  *) fail "OBOS_RELEASE_BUILD must be 0 or 1" ;;
esac

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_IMAGE_KIND=
OBOS_DEBIAN_RELEASE=
OBOS_DEBIAN_COMPONENTS=
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
OBOS_KERNEL_REQUIRED_CONFIG=
OBOS_IMAGE_DEFAULT_SSH=

# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = "rpi4-arm64" ] || fail "profile must be rpi4-arm64"
[ "${OBOS_IMAGE_ARCH}" = "arm64" ] || fail "profile architecture must be arm64"
[ "${OBOS_IMAGE_KIND}" = "rpi-image" ] || fail "profile kind must be rpi-image"
[ "${OBOS_OUTPUT_FORMAT}" = "raw" ] || fail "profile output format must be raw"
[ "${OBOS_OUTPUT_COMPRESSION}" = "xz" ] || fail "profile compression must be xz"
[ "${OBOS_IMAGE_EXTENSION}" = "img.xz" ] || fail "profile extension must be img.xz"
[ "${OBOS_IMAGE_DEFAULT_SSH}" = "disabled" ] || fail "profile SSH default policy must be disabled"

if [ "${RELEASE_BUILD}" = "1" ]; then
  require_clean_release_repo
fi

require_command basename
require_command chroot
require_command cp
require_command cut
require_command date
require_command debootstrap
require_command losetup
require_command mkdir
require_command mkfs.ext4
require_command mkfs.vfat
require_command mount
require_command mountpoint
require_command partprobe
require_command qemu-aarch64-static
require_command sha256sum
require_command sfdisk
require_command tar
require_command truncate
require_command umount
require_command xz

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RAW_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-${STAMP}.img"
XZ_IMAGE="${RAW_IMAGE}.xz"
LATEST_XZ_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-latest.img.xz"
MANIFEST="${XZ_IMAGE}.manifest"
LATEST_MANIFEST="${LATEST_XZ_IMAGE}.manifest"
BUILD_ROOT="${WORK_DIR}/rootfs-${STAMP}"
BOOT_MOUNT="${WORK_DIR}/boot-${STAMP}"
ROOT_MOUNT="${WORK_DIR}/mount-${STAMP}"

trap cleanup EXIT INT TERM

rm -rf "${BUILD_ROOT}" "${BOOT_MOUNT}" "${ROOT_MOUNT}"
mkdir -p "${BUILD_ROOT}" "${BOOT_MOUNT}" "${ROOT_MOUNT}"

truncate -s "${OBOS_IMAGE_MIN_SIZE}" "${RAW_IMAGE}"
sfdisk "${RAW_IMAGE}" <<EOF
label: dos
unit: sectors

start=2048,size=524288,type=c,bootable
start=526336,type=83
EOF

LOOP_DEVICE="$(losetup --find --partscan --show "${RAW_IMAGE}")"
partprobe "${LOOP_DEVICE}" || true

mkfs.vfat -F 32 -n "${OBOS_RPI_BOOT_PARTITION_LABEL}" "${LOOP_DEVICE}p1"
mkfs.ext4 -F -L "${OBOS_RPI_ROOT_PARTITION_LABEL}" "${LOOP_DEVICE}p2"
mount "${LOOP_DEVICE}p2" "${ROOT_MOUNT}"
mkdir -p "${ROOT_MOUNT}/boot"
mount "${LOOP_DEVICE}p1" "${BOOT_MOUNT}"

include_packages="${OBOS_BASE_PACKAGES},${OBOS_RPI_BOOT_PACKAGES}"
debootstrap --arch=arm64 --foreign --components="${OBOS_DEBIAN_COMPONENTS}" --include="${include_packages}" "${OBOS_DEBIAN_RELEASE}" "${BUILD_ROOT}"
cp "$(command -v qemu-aarch64-static)" "${BUILD_ROOT}/usr/bin/qemu-aarch64-static"
chroot "${BUILD_ROOT}" /debootstrap/debootstrap --second-stage

copy_repo_into_root "${BUILD_ROOT}"
mount --bind /dev "${BUILD_ROOT}/dev"
mount -t proc proc "${BUILD_ROOT}/proc"
mount -t sysfs sysfs "${BUILD_ROOT}/sys"
chroot "${BUILD_ROOT}" /bin/sh -c "cd /opt/openbridgeos/${REPO_NAME} && OBOS_DISABLE_SSH=1 sh ${OBOS_PROVISION_SCRIPT} /opt/openbridgeos/${REPO_NAME}"
umount "${BUILD_ROOT}/proc"
umount "${BUILD_ROOT}/sys"
umount "${BUILD_ROOT}/dev"
rm -f "${BUILD_ROOT}/srv/obos/state/first-boot.done"
truncate -s 0 "${BUILD_ROOT}/etc/machine-id"
rm -f "${BUILD_ROOT}/var/lib/dbus/machine-id"
write_fstab "${BUILD_ROOT}"
write_boot_config "${BUILD_ROOT}/boot"
sh "${CHECK_RPI_BOOT_FILES}" "${BUILD_ROOT}"

cp -a "${BUILD_ROOT}/." "${ROOT_MOUNT}/"
cp -a "${BUILD_ROOT}/boot/." "${BOOT_MOUNT}/"

sh "${CHECK_RPI_KERNEL_CONFIG}" "${ROOT_MOUNT}"

umount "${BOOT_MOUNT}"
BOOT_MOUNT=
umount "${ROOT_MOUNT}"
ROOT_MOUNT=
losetup -d "${LOOP_DEVICE}"
LOOP_DEVICE=

xz -T0 -z -f "${RAW_IMAGE}"
sha256sum "${XZ_IMAGE}" > "${XZ_IMAGE}.sha256"
write_manifest "${MANIFEST}" "${XZ_IMAGE}" "${XZ_IMAGE}.sha256" "${STAMP}"
OBOS_MANIFEST_STRICT_FILES=1 sh "${CHECK_RPI_MANIFEST}" "${MANIFEST}" >/dev/null
cp "${XZ_IMAGE}" "${LATEST_XZ_IMAGE}"
cp "${XZ_IMAGE}.sha256" "${LATEST_XZ_IMAGE}.sha256"
cp "${MANIFEST}" "${LATEST_MANIFEST}"

printf 'image: %s\n' "${XZ_IMAGE}"
printf 'checksum: %s\n' "${XZ_IMAGE}.sha256"
printf 'manifest: %s\n' "${MANIFEST}"
