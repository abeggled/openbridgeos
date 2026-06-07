#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CHECKER="scripts/images/check-release-candidate.sh"

fail() {
  echo "release candidate fixture failed: $1" >&2
  exit 1
}

write_qcow2_manifest() {
  image_file="${TMP_DIR}/obos-amd64-vm-test.qcow2"
  base_image_file="${TMP_DIR}/base.qcow2"
  checksum_file="${image_file}.sha256"
  manifest_file="${image_file}.manifest"
  printf 'test qcow2 image\n' > "${image_file}"
  printf 'test qcow2 base image\n' > "${base_image_file}"
  sha256sum "${image_file}" > "${checksum_file}"
  image_sha256="$(cut -d ' ' -f 1 < "${checksum_file}")"
  base_image_sha256="$(sha256sum "${base_image_file}" | cut -d ' ' -f 1)"

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
base_image=${base_image_file}
base_image_url=https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
base_image_sha256=${base_image_sha256}
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

write_validation_record() {
  record_file="$1"
  profile="$2"
  artifact="$3"
  manifest="$4"
  platform="$5"
  hardware_or_vm="$6"
  boot_media="$7"
  network_installer_used="$8"

  cat > "${record_file}" <<EOF
format=obos-image-release-validation-v1
release_candidate=2026.06-test
profile=${profile}
artifact=${artifact}
manifest=${manifest}
signature_verified=yes
checksums_verified=yes
platform=${platform}
hardware_or_vm=${hardware_or_vm}
boot_media=${boot_media}
network_installer_used=${network_installer_used}
first_boot_completed=yes
ssh_default_disabled=yes
security_summary_result=PASS
mvp_readiness_result=PASS
tls_leaf_renewal_plan_result=PASS
tls_trust_exported=yes
rollback_stage_result=PASS
notes=fixture
EOF
}

QCOW2_MANIFEST="$(write_qcow2_manifest)"
RPI_MANIFEST="$(write_rpi_manifest)"
RELEASE_MANIFEST="${TMP_DIR}/obos-release.manifest"

OBOS_REPO_ROOT="$(pwd)" OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/create-release-manifest.sh "${RELEASE_MANIFEST}" "${QCOW2_MANIFEST}" "${RPI_MANIFEST}" >/dev/null

printf 'fixture signature\n' > "${RELEASE_MANIFEST}.minisig"

AMD64_RECORD="${TMP_DIR}/amd64.record"
RPI_RECORD="${TMP_DIR}/rpi.record"

write_validation_record "${AMD64_RECORD}" amd64-vm \
  "${TMP_DIR}/obos-amd64-vm-test.qcow2" "${QCOW2_MANIFEST}" proxmox vm virtual-disk no
write_validation_record "${RPI_RECORD}" rpi4-arm64 \
  "${TMP_DIR}/obos-rpi4-arm64-test.img.xz" "${RPI_MANIFEST}" raspberry-pi-4 hardware nvme yes

sh "${CHECKER}" "${RELEASE_MANIFEST}" "${AMD64_RECORD}" "${RPI_RECORD}" |
  grep -q '^result=PASS$' \
  || fail "valid release candidate did not pass"

if sh "${CHECKER}" "${RELEASE_MANIFEST}" "${AMD64_RECORD}" >/dev/null 2>&1; then
  fail "release candidate without rpi validation was accepted"
fi

DUPLICATE_AMD64_RECORD="${TMP_DIR}/duplicate-amd64.record"
cp "${AMD64_RECORD}" "${DUPLICATE_AMD64_RECORD}"
if sh "${CHECKER}" "${RELEASE_MANIFEST}" "${AMD64_RECORD}" "${RPI_RECORD}" "${DUPLICATE_AMD64_RECORD}" >/dev/null 2>&1; then
  fail "release candidate with duplicate amd64 validation was accepted"
fi

BAD_RECORD="${TMP_DIR}/bad-artifact.record"
cp "${AMD64_RECORD}" "${BAD_RECORD}"
sed -i 's#^artifact=.*$#artifact=/tmp/not-in-release.qcow2#' "${BAD_RECORD}"
if sh "${CHECKER}" "${RELEASE_MANIFEST}" "${BAD_RECORD}" "${RPI_RECORD}" >/dev/null 2>&1; then
  fail "validation record for artifact outside release manifest was accepted"
fi

rm -f "${RELEASE_MANIFEST}.minisig"
if sh "${CHECKER}" "${RELEASE_MANIFEST}" "${AMD64_RECORD}" "${RPI_RECORD}" >/dev/null 2>&1; then
  fail "release candidate without signature was accepted"
fi

echo "release candidate fixture: PASS"
