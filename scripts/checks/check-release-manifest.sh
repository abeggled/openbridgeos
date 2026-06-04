#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fail() {
  echo "release manifest fixture failed: $1" >&2
  exit 1
}

write_qcow2_manifest() {
  image_file="${TMP_DIR}/obos-amd64-vm-test.qcow2"
  checksum_file="${image_file}.sha256"
  manifest_file="${image_file}.manifest"
  printf 'test qcow2 image\n' > "${image_file}"
  sha256sum "${image_file}" > "${checksum_file}"
  image_sha256="$(cut -d ' ' -f 1 < "${checksum_file}")"

  cat > "${manifest_file}" <<EOF
format=obos-qcow2-build-v1
created_at=20260604T000000Z
profile=amd64-vm
architecture=amd64
debian_release=trixie
output_format=qcow2
release_build=1
image=${image_file}
checksum_file=${checksum_file}
image_sha256=${image_sha256}
base_image=${TMP_DIR}/base.qcow2
base_image_url=https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
base_image_sha256=unused
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=test-revision
repo_dirty=false
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF
  printf '%s\n' "${manifest_file}"
}

write_rpi_manifest() {
  image_file="${TMP_DIR}/obos-rpi4-arm64-test.img.xz"
  checksum_file="${image_file}.sha256"
  manifest_file="${image_file}.manifest"
  printf 'test rpi image\n' > "${image_file}"
  sha256sum "${image_file}" > "${checksum_file}"
  image_sha256="$(cut -d ' ' -f 1 < "${checksum_file}")"

  cat > "${manifest_file}" <<EOF
format=obos-rpi-image-build-v1
created_at=20260604T000000Z
profile=rpi4-arm64
architecture=arm64
debian_release=trixie
output_format=raw
output_compression=xz
image_extension=img.xz
release_build=1
image=${image_file}
checksum_file=${checksum_file}
image_sha256=${image_sha256}
network_installer_compatible=true
boot_media=sd,usb,nvme
firmware_mode=raspberry-pi-bootloader
partition_layout=boot-fat32,root-ext4
boot_partition_label=OBOSBOOT
root_partition_label=OBOSROOT
kernel_required_config=CONFIG_BLK_DEV_NVME=y,CONFIG_PCIE_BRCMSTB=y,CONFIG_USB_XHCI_PCI=y
kernel_config_verified=true
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=test-revision
repo_dirty=false
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF
  printf '%s\n' "${manifest_file}"
}

QCOW2_MANIFEST="$(write_qcow2_manifest)"
RPI_MANIFEST="$(write_rpi_manifest)"
RELEASE_MANIFEST="${TMP_DIR}/obos-release.manifest"

OBOS_REPO_ROOT="$(pwd)" OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/create-release-manifest.sh "${RELEASE_MANIFEST}" "${QCOW2_MANIFEST}" "${RPI_MANIFEST}" >/dev/null

SIGNATURE_FILE="${RELEASE_MANIFEST}.minisig"
printf 'unverified fixture signature\n' > "${SIGNATURE_FILE}"

OBOS_MANIFEST_STRICT_FILES=1 OBOS_RELEASE_SIGNATURE_STRICT=1 \
  sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null

grep -q '^format=obos-release-bundle-v1$' "${RELEASE_MANIFEST}" \
  || fail "release manifest format missing"
grep -q '^signature_required=true$' "${RELEASE_MANIFEST}" \
  || fail "release manifest signature requirement missing"
grep -q '^signature_type=minisign$' "${RELEASE_MANIFEST}" \
  || fail "release manifest signature type missing"
grep -q '^artifact_count=2$' "${RELEASE_MANIFEST}" \
  || fail "release manifest artifact count missing"
grep -q '^artifact_1_profile=amd64-vm$' "${RELEASE_MANIFEST}" \
  || fail "qcow2 artifact profile missing"
grep -q '^artifact_2_profile=rpi4-arm64$' "${RELEASE_MANIFEST}" \
  || fail "rpi artifact profile missing"

bad_checksum_file="$(awk -F= '$1 == "artifact_1_checksum_file" { print substr($0, length($1) + 2) }' "${RELEASE_MANIFEST}")"
printf '0000000000000000000000000000000000000000000000000000000000000000  tampered\n' > "${bad_checksum_file}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null 2>&1; then
  fail "tampered artifact checksum file was accepted"
fi

sha256sum "$(awk -F= '$1 == "artifact_1_image" { print substr($0, length($1) + 2) }' "${RELEASE_MANIFEST}")" > "${bad_checksum_file}"
rm -f "${SIGNATURE_FILE}"
if OBOS_MANIFEST_STRICT_FILES=1 OBOS_RELEASE_SIGNATURE_STRICT=1 sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null 2>&1; then
  fail "missing release signature file was accepted"
fi

echo "release manifest fixture: PASS"
