#!/usr/bin/env sh
set -eu

profile_file="${1:-}"
[ -n "${profile_file}" ] || {
  echo "usage: scripts/images/print-image-build-plan.sh <profile.env>" >&2
  exit 2
}
[ -f "${profile_file}" ] || {
  echo "missing profile: ${profile_file}" >&2
  exit 1
}

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_IMAGE_KIND=
OBOS_DEBIAN_RELEASE=
OBOS_BOOT_TARGET=
OBOS_OUTPUT_FORMAT=
OBOS_BASE_PACKAGES=
OBOS_PROVISION_SCRIPT=
OBOS_FIRST_BOOT_SERVICE=
OBOS_NOTES=

# shellcheck disable=SC1090
. "${profile_file}"

cat <<EOF
profile=${OBOS_IMAGE_PROFILE}
architecture=${OBOS_IMAGE_ARCH}
kind=${OBOS_IMAGE_KIND}
debian_release=${OBOS_DEBIAN_RELEASE}
boot_target=${OBOS_BOOT_TARGET}
output_format=${OBOS_OUTPUT_FORMAT}
base_packages=${OBOS_BASE_PACKAGES}
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
notes=${OBOS_NOTES}

build_contract:
  - create Debian ${OBOS_DEBIAN_RELEASE} ${OBOS_IMAGE_ARCH} root filesystem
  - install base packages: ${OBOS_BASE_PACKAGES}
  - copy this repository into the image build context
  - run ${OBOS_PROVISION_SCRIPT} inside the target filesystem or VM
  - do not run first boot during image creation
  - enable ${OBOS_FIRST_BOOT_SERVICE} for target appliance initialization
  - emit ${OBOS_OUTPUT_FORMAT} artifact plus checksum
EOF
