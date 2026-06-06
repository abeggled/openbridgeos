#!/usr/bin/env sh
set -eu

profile="${1:-}"

fail() {
  echo "image validation record template failed: $1" >&2
  exit 1
}

[ -n "${profile}" ] || fail "usage: $0 <amd64-vm|rpi4-arm64>"

case "${profile}" in
  amd64-vm)
    artifact="dist/images/obos-amd64-vm-latest.qcow2"
    manifest="dist/images/obos-amd64-vm-latest.qcow2.manifest"
    platform="<vm-platform>"
    hardware_or_vm="vm"
    boot_media="virtual-disk"
    network_installer_used="no"
    ;;
  rpi4-arm64)
    artifact="dist/images/obos-rpi4-arm64-latest.img.xz"
    manifest="dist/images/obos-rpi4-arm64-latest.img.xz.manifest"
    platform="raspberry-pi-4"
    hardware_or_vm="hardware"
    boot_media="<sd|usb|nvme>"
    network_installer_used="yes"
    ;;
  *)
    fail "unsupported profile: ${profile}"
    ;;
esac

cat <<EOF
format=obos-image-release-validation-v1
release_candidate=<release-candidate>
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
notes=<validation-notes>
EOF
