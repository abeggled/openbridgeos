#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CHECKER="scripts/images/check-image-release-validation-record.sh"

fail() {
  echo "image release validation record fixture failed: $1" >&2
  exit 1
}

cat > "${TMP_DIR}/amd64.record" <<'EOF'
format=obos-image-release-validation-v1
release_candidate=2026.06-test
profile=amd64-vm
artifact=dist/images/obos-amd64-vm-test.qcow2
manifest=dist/images/obos-amd64-vm-test.qcow2.manifest
signature_verified=yes
checksums_verified=yes
platform=proxmox
hardware_or_vm=vm
boot_media=virtual-disk
network_installer_used=no
first_boot_completed=yes
ssh_default_disabled=yes
security_summary_result=PASS
mvp_readiness_result=PASS
tls_leaf_renewal_plan_result=PASS
tls_trust_exported=yes
rollback_stage_result=PASS
notes=fixture
EOF

cat > "${TMP_DIR}/rpi.record" <<'EOF'
format=obos-image-release-validation-v1
release_candidate=2026.06-test
profile=rpi4-arm64
artifact=dist/images/obos-rpi4-arm64-test.img.xz
manifest=dist/images/obos-rpi4-arm64-test.img.xz.manifest
signature_verified=yes
checksums_verified=yes
platform=raspberry-pi-4
hardware_or_vm=hardware
boot_media=nvme
network_installer_used=yes
first_boot_completed=yes
ssh_default_disabled=yes
security_summary_result=PASS
mvp_readiness_result=PASS
tls_leaf_renewal_plan_result=PASS
tls_trust_exported=yes
rollback_stage_result=PASS
notes=fixture
EOF

sh "${CHECKER}" "${TMP_DIR}/amd64.record" | grep -q '^result=PASS$' \
  || fail "valid amd64 record did not pass"

sh "${CHECKER}" "${TMP_DIR}/rpi.record" | grep -q '^result=PASS$' \
  || fail "valid rpi record did not pass"

cp "${TMP_DIR}/amd64.record" "${TMP_DIR}/bad-signature.record"
sed -i 's/^signature_verified=yes$/signature_verified=no/' "${TMP_DIR}/bad-signature.record"
if sh "${CHECKER}" "${TMP_DIR}/bad-signature.record" >/dev/null 2>&1; then
  fail "unsigned record was accepted"
fi

cp "${TMP_DIR}/rpi.record" "${TMP_DIR}/bad-rpi-network-installer.record"
sed -i 's/^network_installer_used=yes$/network_installer_used=no/' "${TMP_DIR}/bad-rpi-network-installer.record"
if sh "${CHECKER}" "${TMP_DIR}/bad-rpi-network-installer.record" >/dev/null 2>&1; then
  fail "rpi record without Network Installer validation was accepted"
fi

cp "${TMP_DIR}/rpi.record" "${TMP_DIR}/bad-rpi-boot.record"
sed -i 's/^boot_media=nvme$/boot_media=sata/' "${TMP_DIR}/bad-rpi-boot.record"
if sh "${CHECKER}" "${TMP_DIR}/bad-rpi-boot.record" >/dev/null 2>&1; then
  fail "rpi record with unsupported boot media was accepted"
fi

echo "image release validation record fixture: PASS"
