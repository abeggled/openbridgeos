#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

IMAGE_FILE="${TMP_DIR}/obos-amd64-vm-test.qcow2"
BASE_IMAGE_FILE="${TMP_DIR}/base-amd64-vm.qcow2"
CHECKSUM_FILE="${IMAGE_FILE}.sha256"
MANIFEST_FILE="${TMP_DIR}/obos-amd64-vm-test.qcow2.manifest"

printf 'test image\n' > "${IMAGE_FILE}"
printf 'test base image\n' > "${BASE_IMAGE_FILE}"

IMAGE_SHA256="$(sha256sum "${IMAGE_FILE}" | cut -d ' ' -f 1)"
BASE_IMAGE_SHA256="$(sha256sum "${BASE_IMAGE_FILE}" | cut -d ' ' -f 1)"
sha256sum "${IMAGE_FILE}" > "${CHECKSUM_FILE}"

cat > "${MANIFEST_FILE}" <<EOF
format=obos-qcow2-build-v1
created_at=20260604T000000Z
profile=amd64-vm
architecture=amd64
debian_release=trixie
output_format=qcow2
release_build=1
image=${IMAGE_FILE}
checksum_file=${CHECKSUM_FILE}
image_sha256=${IMAGE_SHA256}
base_image=${BASE_IMAGE_FILE}
base_image_url=https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
base_image_sha256=${BASE_IMAGE_SHA256}
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=test-revision
repo_dirty=false
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF

OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-qcow2-manifest.sh "${MANIFEST_FILE}" >/dev/null

DIRTY_MANIFEST="${TMP_DIR}/obos-amd64-vm-test-dirty.qcow2.manifest"
sed 's/^repo_dirty=false$/repo_dirty=true/' "${MANIFEST_FILE}" > "${DIRTY_MANIFEST}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-qcow2-manifest.sh "${DIRTY_MANIFEST}" >/dev/null 2>&1; then
  echo "qcow2 manifest fixture failed: dirty release manifest was accepted" >&2
  exit 1
fi

WRONG_DEBIAN_MANIFEST="${TMP_DIR}/obos-amd64-vm-test-wrong-debian.qcow2.manifest"
sed 's/^debian_release=trixie$/debian_release=bookworm/' "${MANIFEST_FILE}" > "${WRONG_DEBIAN_MANIFEST}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-qcow2-manifest.sh "${WRONG_DEBIAN_MANIFEST}" >/dev/null 2>&1; then
  echo "qcow2 manifest fixture failed: non-Trixie release manifest was accepted" >&2
  exit 1
fi

printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "${IMAGE_FILE}" > "${CHECKSUM_FILE}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-qcow2-manifest.sh "${MANIFEST_FILE}" >/dev/null 2>&1; then
  echo "qcow2 manifest fixture failed: checksum file mismatch was accepted" >&2
  exit 1
fi

echo "qcow2 manifest fixture: PASS"
