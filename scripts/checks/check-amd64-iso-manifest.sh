#!/usr/bin/env sh
set -eu

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
image="${tmp_dir}/obos-amd64-installer-test.iso"
checksum="${image}.sha256"
manifest="${image}.manifest"

printf 'fixture ISO\n' > "${image}"
sha256sum "${image}" > "${checksum}"
sha="$(cut -d ' ' -f 1 < "${checksum}")"
cat > "${manifest}" <<EOF
format=obos-amd64-iso-build-v1
created_at=20261014T000000Z
profile=amd64-installer
architecture=amd64
debian_release=trixie
output_format=iso
image_extension=iso
hybrid=true
boot_targets=bios,uefi
installer_mode=live
release_build=1
image=${image}
checksum_file=${checksum}
image_sha256=${sha}
provision_script=scripts/bootstrap/provision-debian.sh
first_boot_service=obos-first-boot.service
repo_revision=fixture
repo_dirty=false
ssh_default=disabled
first_boot_pending=true
contains_secrets=false
EOF

OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-amd64-iso-manifest.sh "${manifest}" >/dev/null
printf 'tampered\n' >> "${image}"
if OBOS_MANIFEST_STRICT_FILES=1 sh scripts/images/check-amd64-iso-manifest.sh "${manifest}" >/dev/null 2>&1; then
  echo "amd64 ISO manifest fixture failed: tampered ISO was accepted" >&2
  exit 1
fi
echo "amd64 ISO manifest fixture: PASS"
