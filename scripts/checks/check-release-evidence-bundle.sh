#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}"

CHECKER="scripts/images/check-release-evidence-bundle.sh"
BUNDLE_DIR="${TMP_DIR}/bundle"
mkdir -p "${BUNDLE_DIR}"

fail() {
  echo "release evidence bundle fixture failed: $1" >&2
  exit 1
}

write_qcow2_manifest() {
  image_file="${BUNDLE_DIR}/obos-amd64-vm-test.qcow2"
  base_image_file="${BUNDLE_DIR}/base.qcow2"
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
  image_file="${BUNDLE_DIR}/obos-rpi4-arm64-test.img.xz"
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

QCOW2_MANIFEST="$(write_qcow2_manifest)"
RPI_MANIFEST="$(write_rpi_manifest)"
RELEASE_MANIFEST="${BUNDLE_DIR}/obos-release.manifest"

OBOS_REPO_ROOT="$(pwd)" OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/create-release-manifest.sh "${RELEASE_MANIFEST}" "${QCOW2_MANIFEST}" "${RPI_MANIFEST}" >/dev/null

printf 'fixture signature\n' > "${RELEASE_MANIFEST}.minisig"
printf 'RWQfixturepublickey\n' > "${BUNDLE_DIR}/obos-release.minisign.pub"

write_validation_record "${BUNDLE_DIR}/validation-amd64-vm.record" amd64-vm \
  "${BUNDLE_DIR}/obos-amd64-vm-test.qcow2" "${QCOW2_MANIFEST}" proxmox vm virtual-disk no
write_validation_record "${BUNDLE_DIR}/validation-rpi4-arm64.record" rpi4-arm64 \
  "${BUNDLE_DIR}/obos-rpi4-arm64-test.img.xz" "${RPI_MANIFEST}" raspberry-pi-4 hardware nvme yes

cat > "${BUNDLE_DIR}/release-notes.md" <<'EOF'
# Release Notes

minisign_public_key=RWQfixturepublickey
minisign_public_key_fingerprint=fixture
validation-amd64-vm.record
validation-rpi4-arm64.record
tls_leaf_renewal_plan_result=PASS
compose_image_pinning=not_run

## Known Gaps

- fixture

## Upgrade And Migration Notes

- raw unencrypted backups are blocked for web download or migration
EOF

PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" |
  grep -q '^result=PASS$' \
  || fail "valid release evidence bundle did not pass"

mv "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.missing"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle without release notes was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.missing" "${BUNDLE_DIR}/release-notes.md"

mv "${BUNDLE_DIR}/validation-rpi4-arm64.record" "${BUNDLE_DIR}/validation-rpi4-arm64.missing"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle without rpi validation record was accepted"
fi
mv "${BUNDLE_DIR}/validation-rpi4-arm64.missing" "${BUNDLE_DIR}/validation-rpi4-arm64.record"

cp "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.good"
grep -v 'raw unencrypted backups' "${BUNDLE_DIR}/release-notes.good" > "${BUNDLE_DIR}/release-notes.md"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle without backup safety note was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.good" "${BUNDLE_DIR}/release-notes.md"

cp "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.good"
grep -v 'tls_leaf_renewal_plan_result=' "${BUNDLE_DIR}/release-notes.good" > "${BUNDLE_DIR}/release-notes.md"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle without TLS leaf renewal plan evidence was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.good" "${BUNDLE_DIR}/release-notes.md"

cp "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.good"
grep -v 'compose_image_pinning=' "${BUNDLE_DIR}/release-notes.good" > "${BUNDLE_DIR}/release-notes.md"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle without Compose image pinning evidence was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.good" "${BUNDLE_DIR}/release-notes.md"

cp "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.good"
sed 's/^minisign_public_key_fingerprint=.*/minisign_public_key_fingerprint=/' "${BUNDLE_DIR}/release-notes.good" > "${BUNDLE_DIR}/release-notes.md"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle with empty release notes fingerprint was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.good" "${BUNDLE_DIR}/release-notes.md"

cp "${BUNDLE_DIR}/release-notes.md" "${BUNDLE_DIR}/release-notes.good"
sed 's/^compose_image_pinning=.*/compose_image_pinning=<compose-result>/' "${BUNDLE_DIR}/release-notes.good" > "${BUNDLE_DIR}/release-notes.md"
if PATH="${FAKE_BIN}:$PATH" sh "${CHECKER}" "${BUNDLE_DIR}" >/dev/null 2>&1; then
  fail "bundle with release notes placeholder evidence was accepted"
fi
mv "${BUNDLE_DIR}/release-notes.good" "${BUNDLE_DIR}/release-notes.md"

echo "release evidence bundle fixture: PASS"
