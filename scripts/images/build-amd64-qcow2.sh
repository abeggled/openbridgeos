#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/amd64-vm.env}"
WORK_DIR="${OBOS_IMAGE_WORK_DIR:-build/images/amd64-vm}"
OUTPUT_DIR="${OBOS_IMAGE_OUTPUT_DIR:-dist/images}"
REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
BASE_IMAGE="${OBOS_QCOW2_BASE_IMAGE:-}"

fail() {
  echo "amd64 qcow2 build failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_IMAGE_KIND=
OBOS_DEBIAN_RELEASE=
OBOS_BOOT_TARGET=
OBOS_OUTPUT_FORMAT=
OBOS_BASE_PACKAGES=
OBOS_PROVISION_SCRIPT=
OBOS_FIRST_BOOT_SERVICE=
OBOS_QCOW2_BASE_IMAGE_URL=
OBOS_QCOW2_MIN_SIZE=
OBOS_QCOW2_BUILDER=
OBOS_QCOW2_REQUIRED_TOOLS=
OBOS_IMAGE_DEFAULT_SSH=

# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = "amd64-vm" ] || fail "profile must be amd64-vm"
[ "${OBOS_IMAGE_ARCH}" = "amd64" ] || fail "profile architecture must be amd64"
[ "${OBOS_OUTPUT_FORMAT}" = "qcow2" ] || fail "profile output format must be qcow2"
[ "${OBOS_QCOW2_BUILDER}" = "virt-customize" ] || fail "profile builder must be virt-customize"

require_command cp
require_command mkdir
require_command qemu-img
require_command sha256sum
require_command virt-customize
require_command virt-sysprep

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

if [ -z "${BASE_IMAGE}" ]; then
  BASE_IMAGE="${WORK_DIR}/base-${OBOS_DEBIAN_RELEASE}-${OBOS_IMAGE_ARCH}.qcow2"
  if [ ! -f "${BASE_IMAGE}" ]; then
    require_command curl
    curl --fail --location --output "${BASE_IMAGE}" "${OBOS_QCOW2_BASE_IMAGE_URL}"
  fi
fi

[ -f "${BASE_IMAGE}" ] || fail "base qcow2 not found: ${BASE_IMAGE}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-${STAMP}.qcow2"
LATEST_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-latest.qcow2"

cp "${BASE_IMAGE}" "${OUTPUT_IMAGE}"
qemu-img resize "${OUTPUT_IMAGE}" "${OBOS_QCOW2_MIN_SIZE}"

virt-customize -a "${OUTPUT_IMAGE}" \
  --mkdir /opt/openbridgeos \
  --copy-in "${REPO_ROOT}:/opt/openbridgeos" \
  --run-command "cd /opt/openbridgeos/openbridgeos && OBOS_DISABLE_SSH=1 ${OBOS_PROVISION_SCRIPT} /opt/openbridgeos/openbridgeos" \
  --run-command "systemctl enable ${OBOS_FIRST_BOOT_SERVICE}" \
  --run-command "rm -f /etc/obos/first-boot.done" \
  --run-command "truncate -s 0 /etc/machine-id" \
  --run-command "rm -f /var/lib/dbus/machine-id" \
  --run-command "apt-get clean"

virt-sysprep -a "${OUTPUT_IMAGE}" \
  --operations bash-history,logfiles,machine-id,net-hostname,tmp-files,udev-persistent-net

qemu-img info "${OUTPUT_IMAGE}"
sha256sum "${OUTPUT_IMAGE}" > "${OUTPUT_IMAGE}.sha256"
cp "${OUTPUT_IMAGE}" "${LATEST_IMAGE}"
cp "${OUTPUT_IMAGE}.sha256" "${LATEST_IMAGE}.sha256"

printf 'image: %s\n' "${OUTPUT_IMAGE}"
printf 'checksum: %s\n' "${OUTPUT_IMAGE}.sha256"
