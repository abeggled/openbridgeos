#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}"

fail() {
  echo "release manifest fixture failed: $1" >&2
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

QCOW2_MANIFEST="$(write_qcow2_manifest)"
RPI_MANIFEST="$(write_rpi_manifest)"
RELEASE_MANIFEST="${TMP_DIR}/obos-release.manifest"

OBOS_REPO_ROOT="$(pwd)" OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/create-release-manifest.sh "${RELEASE_MANIFEST}" "${QCOW2_MANIFEST}" "${RPI_MANIFEST}" >/dev/null

SIGNATURE_FILE="${RELEASE_MANIFEST}.minisig"
printf 'unverified fixture signature\n' > "${SIGNATURE_FILE}"

OBOS_MANIFEST_STRICT_FILES=1 OBOS_RELEASE_SIGNATURE_STRICT=1 \
  sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null

cat > "${FAKE_BIN}/minisign" <<'EOF'
#!/usr/bin/env sh
set -eu

[ "${1:-}" = "-Vm" ] || exit 1
[ -f "${2:-}" ] || exit 1
[ "${3:-}" = "-x" ] || exit 1
[ -s "${4:-}" ] || exit 1
[ "${5:-}" = "-P" ] || exit 1
[ -n "${6:-}" ] || exit 1
exit 0
EOF
chmod 0755 "${FAKE_BIN}/minisign"

PATH="${FAKE_BIN}:$PATH" OBOS_MANIFEST_STRICT_FILES=1 OBOS_RELEASE_SIGNATURE_STRICT=1 \
  OBOS_RELEASE_MINISIGN_PUBLIC_KEY="RWQfixturepublickey" \
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

missing_rpi_manifest="${TMP_DIR}/missing-rpi-release.manifest"
awk '$1 != "artifact_count=2" && $1 !~ /^artifact_2_/ { print }' "${RELEASE_MANIFEST}" > "${missing_rpi_manifest}"
printf 'artifact_count=1\n' >> "${missing_rpi_manifest}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-release-manifest.sh "${missing_rpi_manifest}" >/dev/null 2>&1; then
  fail "release manifest missing rpi4-arm64 was accepted"
fi

duplicate_amd64_manifest="${TMP_DIR}/duplicate-amd64-release.manifest"
awk '
  /^artifact_2_profile=/ {
    print "artifact_2_profile=amd64-vm"
    next
  }
  { print }
' "${RELEASE_MANIFEST}" > "${duplicate_amd64_manifest}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-release-manifest.sh "${duplicate_amd64_manifest}" >/dev/null 2>&1; then
  fail "release manifest duplicate amd64-vm was accepted"
fi

image_file="$(awk -F= '$1 == "artifact_1_image" { print substr($0, length($1) + 2) }' "${RELEASE_MANIFEST}")"
mv "${image_file}" "${image_file}.missing"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null 2>&1; then
  fail "missing release image file was accepted"
fi
mv "${image_file}.missing" "${image_file}"

printf 'tampered release image\n' >> "${image_file}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-release-manifest.sh "${RELEASE_MANIFEST}" >/dev/null 2>&1; then
  fail "tampered release image file was accepted"
fi
printf 'test qcow2 image\n' > "${image_file}"

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
