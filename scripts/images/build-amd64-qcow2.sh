#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/amd64-vm.env}"
WORK_DIR="${OBOS_IMAGE_WORK_DIR:-build/images/amd64-vm}"
OUTPUT_DIR="${OBOS_IMAGE_OUTPUT_DIR:-dist/images}"
REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
REPO_NAME="$(basename -- "${REPO_ROOT}")"
IMAGE_REPO_DIR="/opt/openbridgeos/${REPO_NAME}"
BASE_IMAGE="${OBOS_QCOW2_BASE_IMAGE:-}"
BASE_IMAGE_SHA256="${OBOS_QCOW2_BASE_IMAGE_SHA256:-}"
RELEASE_BUILD="${OBOS_RELEASE_BUILD:-0}"
VALIDATE_IMAGE_PROFILES="${REPO_ROOT}/scripts/images/validate-image-profiles.sh"

fail() {
  echo "amd64 qcow2 build failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

repo_revision() {
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse HEAD
  else
    echo unknown
  fi
}

verify_release_build_inputs() {
  case "${RELEASE_BUILD}" in
    0|1) ;;
    *) fail "OBOS_RELEASE_BUILD must be 0 or 1" ;;
  esac

  if [ "${RELEASE_BUILD}" = "1" ] && [ -z "${BASE_IMAGE_SHA256}" ]; then
    fail "release builds require OBOS_QCOW2_BASE_IMAGE_SHA256"
  fi
}

verify_base_image_hash() {
  base_image_file="$1"

  if [ -z "${BASE_IMAGE_SHA256}" ]; then
    return 0
  fi

  actual_sha256="$(sha256sum "${base_image_file}" | cut -d ' ' -f 1)"
  [ "${actual_sha256}" = "${BASE_IMAGE_SHA256}" ] \
    || fail "base qcow2 sha256 mismatch for ${base_image_file}"

  printf 'base image sha256 verified: %s\n' "${actual_sha256}"
}

write_manifest() {
  manifest_file="$1"
  image_file="$2"
  checksum_file="$3"
  base_image_file="$4"
  created_at="$5"

  image_sha256="$(cut -d ' ' -f 1 < "${checksum_file}")"
  base_sha256="$(sha256sum "${base_image_file}" | cut -d ' ' -f 1)"
  revision="$(repo_revision)"

  cat > "${manifest_file}" <<EOF
format=obos-qcow2-build-v1
created_at=${created_at}
profile=${OBOS_IMAGE_PROFILE}
architecture=${OBOS_IMAGE_ARCH}
debian_release=${OBOS_DEBIAN_RELEASE}
output_format=${OBOS_OUTPUT_FORMAT}
release_build=${RELEASE_BUILD}
image=${image_file}
image_sha256=${image_sha256}
base_image=${base_image_file}
base_image_url=${OBOS_QCOW2_BASE_IMAGE_URL}
base_image_sha256=${base_sha256}
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
repo_revision=${revision}
ssh_default=${OBOS_IMAGE_DEFAULT_SSH}
first_boot_pending=true
contains_secrets=false
EOF
}

[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"
[ -f "${VALIDATE_IMAGE_PROFILES}" ] || fail "missing image profile validator: ${VALIDATE_IMAGE_PROFILES}"
sh "${VALIDATE_IMAGE_PROFILES}" "${PROFILE_FILE}" >/dev/null
verify_release_build_inputs

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_DEBIAN_RELEASE=
OBOS_OUTPUT_FORMAT=
OBOS_PROVISION_SCRIPT=
OBOS_FIRST_BOOT_SERVICE=
OBOS_QCOW2_BASE_IMAGE_URL=
OBOS_QCOW2_MIN_SIZE=
OBOS_QCOW2_BUILDER=
OBOS_IMAGE_DEFAULT_SSH=

# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = "amd64-vm" ] || fail "profile must be amd64-vm"
[ "${OBOS_IMAGE_ARCH}" = "amd64" ] || fail "profile architecture must be amd64"
[ "${OBOS_OUTPUT_FORMAT}" = "qcow2" ] || fail "profile output format must be qcow2"
[ "${OBOS_QCOW2_BUILDER}" = "virt-customize" ] || fail "profile builder must be virt-customize"

require_command basename
require_command cp
require_command curl
require_command cut
require_command date
require_command mkdir
require_command qemu-img
require_command sha256sum
require_command virt-customize
require_command virt-sysprep

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

if [ -z "${BASE_IMAGE}" ]; then
  BASE_IMAGE="${WORK_DIR}/base-${OBOS_IMAGE_PROFILE}.qcow2"
  if [ ! -f "${BASE_IMAGE}" ]; then
    curl --fail --location --output "${BASE_IMAGE}" "${OBOS_QCOW2_BASE_IMAGE_URL}"
  fi
fi

[ -f "${BASE_IMAGE}" ] || fail "base qcow2 not found: ${BASE_IMAGE}"
verify_base_image_hash "${BASE_IMAGE}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-${STAMP}.qcow2"
LATEST_IMAGE="${OUTPUT_DIR}/obos-${OBOS_IMAGE_PROFILE}-latest.qcow2"
MANIFEST="${OUTPUT_IMAGE}.manifest"
LATEST_MANIFEST="${LATEST_IMAGE}.manifest"

cp "${BASE_IMAGE}" "${OUTPUT_IMAGE}"
qemu-img resize "${OUTPUT_IMAGE}" "${OBOS_QCOW2_MIN_SIZE}"

virt-customize -a "${OUTPUT_IMAGE}" \
  --mkdir /opt/openbridgeos \
  --copy-in "${REPO_ROOT}:/opt/openbridgeos" \
  --run-command "cd ${IMAGE_REPO_DIR} && OBOS_DISABLE_SSH=1 ${OBOS_PROVISION_SCRIPT} ${IMAGE_REPO_DIR}" \
  --run-command "systemctl enable ${OBOS_FIRST_BOOT_SERVICE}" \
  --run-command "rm -f /etc/obos/first-boot.done" \
  --run-command "truncate -s 0 /etc/machine-id" \
  --run-command "rm -f /var/lib/dbus/machine-id" \
  --run-command "apt-get clean"

virt-sysprep -a "${OUTPUT_IMAGE}" \
  --operations bash-history,logfiles,machine-id,net-hostname,tmp-files,udev-persistent-net

qemu-img info "${OUTPUT_IMAGE}"
sha256sum "${OUTPUT_IMAGE}" > "${OUTPUT_IMAGE}.sha256"
write_manifest "${MANIFEST}" "${OUTPUT_IMAGE}" "${OUTPUT_IMAGE}.sha256" "${BASE_IMAGE}" "${STAMP}"
cp "${OUTPUT_IMAGE}" "${LATEST_IMAGE}"
cp "${OUTPUT_IMAGE}.sha256" "${LATEST_IMAGE}.sha256"
cp "${MANIFEST}" "${LATEST_MANIFEST}"

printf 'image: %s\n' "${OUTPUT_IMAGE}"
printf 'checksum: %s\n' "${OUTPUT_IMAGE}.sha256"
printf 'manifest: %s\n' "${MANIFEST}"
