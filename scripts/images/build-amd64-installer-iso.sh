#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/amd64-installer.env}"
WORK_DIR="${OBOS_IMAGE_WORK_DIR:-build/images/amd64-installer}"
OUTPUT_DIR="${OBOS_IMAGE_OUTPUT_DIR:-dist/images}"
REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
REPO_NAME="$(basename -- "${REPO_ROOT}")"
RELEASE_BUILD="${OBOS_RELEASE_BUILD:-0}"
IMAGE_VERSION="${OBOS_IMAGE_VERSION:-}"
VALIDATOR="${REPO_ROOT}/scripts/images/validate-image-profiles.sh"
PREFLIGHT="${REPO_ROOT}/scripts/images/check-amd64-iso-build-host.sh"
MANIFEST_CHECK="${REPO_ROOT}/scripts/images/check-amd64-iso-manifest.sh"
RUNTIME_CHECK="${REPO_ROOT}/scripts/images/check-amd64-iso-runtime.sh"
RUNTIME_PACKAGES="${REPO_ROOT}/packaging/images/obos-runtime-packages.list.chroot"

fail() { echo "amd64 installer ISO build failed: $1" >&2; exit 1; }

repo_revision() {
  git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown
}

repo_dirty() {
  if git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    [ -z "$(git -C "${REPO_ROOT}" status --porcelain)" ] && echo false || echo true
  else
    echo unknown
  fi
}

[ "$(id -u)" -eq 0 ] || fail "image build must run as root"
[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"
[ -x "${RUNTIME_CHECK}" ] || fail "missing ISO runtime checker: ${RUNTIME_CHECK}"
[ -s "${RUNTIME_PACKAGES}" ] || fail "missing runtime package list: ${RUNTIME_PACKAGES}"
(cd "${REPO_ROOT}" && OBOS_IMAGE_PROFILE_FILE="${PROFILE_FILE}" sh "${PREFLIGHT}")
sh "${VALIDATOR}" "${PROFILE_FILE}" >/dev/null
case "${RELEASE_BUILD}" in 0|1) ;; *) fail "OBOS_RELEASE_BUILD must be 0 or 1" ;; esac
if [ "${RELEASE_BUILD}" = 1 ]; then
  [ "$(repo_dirty)" = false ] || fail "release builds require a clean git tree"
  printf '%s\n' "${IMAGE_VERSION}" | grep -Eq '^[0-9]+([.][0-9]+){1,3}([+~-][A-Za-z0-9.]+)?$' \
    || fail "release builds require a valid OBOS_IMAGE_VERSION"
fi

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_DEBIAN_RELEASE=
OBOS_DEBIAN_COMPONENTS=
OBOS_OUTPUT_FORMAT=
OBOS_IMAGE_EXTENSION=
OBOS_PROVISION_SCRIPT=
OBOS_FIRST_BOOT_SERVICE=
OBOS_ISO_BUILDER=
OBOS_ISO_BOOTLOADERS=
OBOS_ISO_INSTALLER_MODE=
OBOS_ISO_HYBRID=
OBOS_IMAGE_DEFAULT_SSH=
# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = amd64-installer ] || fail "profile must be amd64-installer"
[ "${OBOS_IMAGE_ARCH}" = amd64 ] || fail "architecture must be amd64"
[ "${OBOS_OUTPUT_FORMAT}" = iso ] || fail "output format must be iso"
[ "${OBOS_ISO_BUILDER}" = live-build ] || fail "ISO builder must be live-build"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
IMAGE_ID="${IMAGE_VERSION:-${STAMP}}"
VOLUME_ID="OBOS_$(printf '%s' "${IMAGE_ID}" | tr '.+~-' '____')"
BUILD_DIR="${WORK_DIR}/live-build-${IMAGE_ID}"
OUTPUT_IMAGE="${OUTPUT_DIR}/obos-amd64-installer-${IMAGE_ID}.iso"
CHECKSUM_FILE="${OUTPUT_IMAGE}.sha256"
MANIFEST_FILE="${OUTPUT_IMAGE}.manifest"
LATEST_IMAGE="${OUTPUT_DIR}/obos-amd64-installer-latest.iso"
INCLUDE_REPO="${BUILD_DIR}/config/includes.chroot/opt/openbridgeos/${REPO_NAME}"
HOOK_FILE="${BUILD_DIR}/config/hooks/live/0100-obos.hook.chroot"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
(
  cd "${BUILD_DIR}"
  lb config \
    --mode debian \
    --distribution "${OBOS_DEBIAN_RELEASE}" \
    --architectures amd64 \
    --archive-areas "$(printf '%s' "${OBOS_DEBIAN_COMPONENTS}" | tr ',' ' ')" \
    --binary-image iso-hybrid \
    --bootloaders "${OBOS_ISO_BOOTLOADERS}" \
    --debian-installer live \
    --debian-installer-gui true \
    --uefi-secure-boot auto \
    --iso-application "open bridge operating system" \
    --iso-publisher "openbridgeos" \
    --iso-volume "${VOLUME_ID}" \
    --source false \
    --updates true
)

mkdir -p "${INCLUDE_REPO}" "$(dirname -- "${HOOK_FILE}")" "${BUILD_DIR}/config/package-lists"
tar -C "${REPO_ROOT}" --exclude ./.git --exclude ./build --exclude ./dist -cf - . \
  | tar -C "${INCLUDE_REPO}" -xf -
cat > "${BUILD_DIR}/config/package-lists/obos.list.chroot" <<'EOF'
live-boot
live-config
systemd-sysv
openssh-client
EOF
cp "${RUNTIME_PACKAGES}" "${BUILD_DIR}/config/package-lists/obos-runtime.list.chroot"
cat > "${HOOK_FILE}" <<EOF
#!/bin/sh
set -eu
cd /opt/openbridgeos/${REPO_NAME}
OBOS_DISABLE_SSH=1 OBOS_APPLY_RUNTIME_HARDENING=0 OBOS_IMAGE_BUILD=1 OBOS_VERSION=${IMAGE_ID} \
  sh ${OBOS_PROVISION_SCRIPT} /opt/openbridgeos/${REPO_NAME}
rm -f /srv/obos/state/first-boot.done /var/lib/dbus/machine-id
truncate -s 0 /etc/machine-id
apt-get clean
EOF
chmod 0755 "${HOOK_FILE}"

(cd "${BUILD_DIR}" && lb build)
sh "${RUNTIME_CHECK}" "${BUILD_DIR}" "${RUNTIME_PACKAGES}"
[ -s "${BUILD_DIR}/live-image-amd64.hybrid.iso" ] || fail "live-build ISO output missing"
mv "${BUILD_DIR}/live-image-amd64.hybrid.iso" "${OUTPUT_IMAGE}"
sha256sum "${OUTPUT_IMAGE}" > "${CHECKSUM_FILE}"
image_sha256="$(cut -d ' ' -f 1 < "${CHECKSUM_FILE}")"
cat > "${MANIFEST_FILE}" <<EOF
format=obos-amd64-iso-build-v1
created_at=${STAMP}
profile=${OBOS_IMAGE_PROFILE}
architecture=${OBOS_IMAGE_ARCH}
debian_release=${OBOS_DEBIAN_RELEASE}
output_format=${OBOS_OUTPUT_FORMAT}
image_extension=${OBOS_IMAGE_EXTENSION}
hybrid=${OBOS_ISO_HYBRID}
boot_targets=${OBOS_BOOT_TARGET}
installer_mode=${OBOS_ISO_INSTALLER_MODE}
release_build=${RELEASE_BUILD}
image=${OUTPUT_IMAGE}
checksum_file=${CHECKSUM_FILE}
image_sha256=${image_sha256}
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
repo_revision=$(repo_revision)
repo_dirty=$(repo_dirty)
ssh_default=${OBOS_IMAGE_DEFAULT_SSH}
first_boot_pending=true
contains_secrets=false
EOF
OBOS_MANIFEST_STRICT_FILES=1 sh "${MANIFEST_CHECK}" "${MANIFEST_FILE}" >/dev/null
cp "${OUTPUT_IMAGE}" "${LATEST_IMAGE}"
cp "${CHECKSUM_FILE}" "${LATEST_IMAGE}.sha256"
cp "${MANIFEST_FILE}" "${LATEST_IMAGE}.manifest"
printf 'image: %s\nchecksum: %s\nmanifest: %s\n' "${OUTPUT_IMAGE}" "${CHECKSUM_FILE}" "${MANIFEST_FILE}"
