#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

IMAGE_FILE="${TMP_DIR}/obos-amd64-vm-test.qcow2"
BASE_IMAGE_FILE="${TMP_DIR}/base-amd64-vm.qcow2"
MANIFEST_FILE="${TMP_DIR}/obos-amd64-vm-test.qcow2.manifest"

printf 'test image\n' > "${IMAGE_FILE}"
printf 'test base image\n' > "${BASE_IMAGE_FILE}"

IMAGE_SHA256="$(sha256sum "${IMAGE_FILE}" | cut -d ' ' -f 1)"
BASE_IMAGE_SHA256="$(sha256sum "${BASE_IMAGE_FILE}" | cut -d ' ' -f 1)"

cat > "${MANIFEST_FILE}" <<EOF
format=obos-qcow2-build-v1
created_at=20260604T000000Z
profile=amd64-vm
architecture=amd64
debian_release=trixie
output_format=qcow2
release_build=1
image=${IMAGE_FILE}
image_sha256=${IMAGE_SHA256}
base_image=${BASE_IMAGE_FILE}
base_image_url=https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
base_image_sha256=${BASE_IMAGE_SHA256}
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=test-revision
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF

OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-qcow2-manifest.sh "${MANIFEST_FILE}" >/dev/null

echo "qcow2 manifest fixture: PASS"
