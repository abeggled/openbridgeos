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
CHECK_AMD64_BUILD_HOST="${REPO_ROOT}/scripts/images/check-amd64-qcow2-build-host.sh"
CHECK_QCOW2_MANIFEST="${REPO_ROOT}/scripts/images/check-qcow2-manifest.sh"

fail() {
  echo "amd64 qcow2 build failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

run_build_host_preflight() {
  case "${PROFILE_FILE}" in
    /*) profile_arg="${PROFILE_FILE}" ;;
    *) profile_arg="$(pwd)/${PROFILE_FILE}" ;;
  esac

  (cd "${REPO_ROOT}" && OBOS_IMAGE_PROFILE_FILE="${profile_arg}" sh "${CHECK_AMD64_BUILD_HOST}")
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

verify_release_build_inputs() {
  case "${RELEASE_BUILD}" in
    0|1) ;;
    *) fail "OBOS_RELEASE_BUILD must be 0 or 1" ;;
  esac

  if [ "${RELEASE_BUILD}" = "1" ] && [ -z "${BASE_IMAGE_SHA256}" ]; then
    fail "release builds require OBOS_QCOW2_BASE_IMAGE_SHA256"
  fi

  if [ "${RELEASE_BUILD}" = "1" ]; then
    require_clean_release_repo
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
checksum_file=${checksum_file}
image_sha256=${image_sha256}
base_image=${base_image_file}
base_image_url=${OBOS_QCOW2_BASE_IMAGE_URL}
base_image_sha256=${base_sha256}
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
repo_revision=${revision}
repo_dirty=$(repo_dirty)
ssh_default=${OBOS_IMAGE_DEFAULT_SSH}
first_boot_pending=true
contains_secrets=false
EOF
}

[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"
[ -f "${VALIDATE_IMAGE_PROFILES}" ] || fail "missing image profile validator: ${VALIDATE_IMAGE_PROFILES}"
[ -f "${CHECK_AMD64_BUILD_HOST}" ] || fail "missing build host preflight: ${CHECK_AMD64_BUILD_HOST}"
[ -f "${CHECK_QCOW2_MANIFEST}" ] || fail "missing manifest checker: ${CHECK_QCOW2_MANIFEST}"
run_build_host_preflight
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
require_command rm
require_command sha256sum
require_command tar
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
REPO_STAGING_PARENT="${WORK_DIR}/repo-staging-${STAMP}"
STAGED_REPO_DIR="${REPO_STAGING_PARENT}/${REPO_NAME}"

cp "${BASE_IMAGE}" "${OUTPUT_IMAGE}"
qemu-img resize "${OUTPUT_IMAGE}" "${OBOS_QCOW2_MIN_SIZE}"

rm -rf "${REPO_STAGING_PARENT}"
mkdir -p "${STAGED_REPO_DIR}"
tar -C "${REPO_ROOT}" \
  --exclude ./.git \
  --exclude ./build \
  --exclude ./dist \
  --exclude '*.qcow2' \
  --exclude '*.img' \
  --exclude '*.img.xz' \
  -cf - . | tar -C "${STAGED_REPO_DIR}" -xf -

virt-customize -a "${OUTPUT_IMAGE}" \
  --mkdir /opt/openbridgeos \
  --copy-in "${STAGED_REPO_DIR}:/opt/openbridgeos" \
  --run-command "cd ${IMAGE_REPO_DIR} && OBOS_DISABLE_SSH=1 ${OBOS_PROVISION_SCRIPT} ${IMAGE_REPO_DIR}" \
  --run-command "systemctl enable ${OBOS_FIRST_BOOT_SERVICE}" \
  --run-command "rm -f /srv/obos/state/first-boot.done" \
  --run-command "truncate -s 0 /etc/machine-id" \
  --run-command "rm -f /var/lib/dbus/machine-id" \
  --run-command "apt-get clean"

virt-sysprep -a "${OUTPUT_IMAGE}" \
  --operations bash-history,logfiles,machine-id,net-hostname,tmp-files,udev-persistent-net

qemu-img info "${OUTPUT_IMAGE}"
sha256sum "${OUTPUT_IMAGE}" > "${OUTPUT_IMAGE}.sha256"
write_manifest "${MANIFEST}" "${OUTPUT_IMAGE}" "${OUTPUT_IMAGE}.sha256" "${BASE_IMAGE}" "${STAMP}"
OBOS_MANIFEST_STRICT_FILES=1 sh "${CHECK_QCOW2_MANIFEST}" "${MANIFEST}" >/dev/null
cp "${OUTPUT_IMAGE}" "${LATEST_IMAGE}"
cp "${OUTPUT_IMAGE}.sha256" "${LATEST_IMAGE}.sha256"
cp "${MANIFEST}" "${LATEST_MANIFEST}"

printf 'image: %s\n' "${OUTPUT_IMAGE}"
printf 'checksum: %s\n' "${OUTPUT_IMAGE}.sha256"
printf 'manifest: %s\n' "${MANIFEST}"
