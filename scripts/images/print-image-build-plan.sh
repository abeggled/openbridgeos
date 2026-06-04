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
OBOS_DEBIAN_COMPONENTS=
OBOS_BOOT_TARGET=
OBOS_OUTPUT_FORMAT=
OBOS_OUTPUT_COMPRESSION=
OBOS_IMAGE_EXTENSION=
OBOS_IMAGE_MIN_SIZE=
OBOS_BASE_PACKAGES=
OBOS_RPI_BOOT_PACKAGES=
OBOS_PROVISION_SCRIPT=
OBOS_FIRST_BOOT_SERVICE=
OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE=
OBOS_RPI_BOOT_MEDIA=
OBOS_RPI_FIRMWARE_MODE=
OBOS_RPI_PARTITION_LAYOUT=
OBOS_RPI_BOOT_PARTITION_LABEL=
OBOS_RPI_ROOT_PARTITION_LABEL=
OBOS_RPI_REQUIRED_TOOLS=
OBOS_KERNEL_REQUIRED_CONFIG=
OBOS_QCOW2_BASE_IMAGE_URL=
OBOS_QCOW2_MIN_SIZE=
OBOS_QCOW2_BUILDER=
OBOS_QCOW2_REQUIRED_TOOLS=
OBOS_IMAGE_DEFAULT_SSH=
OBOS_NOTES=

# shellcheck disable=SC1090
. "${profile_file}"

cat <<EOF
profile=${OBOS_IMAGE_PROFILE}
architecture=${OBOS_IMAGE_ARCH}
kind=${OBOS_IMAGE_KIND}
debian_release=${OBOS_DEBIAN_RELEASE}
debian_components=${OBOS_DEBIAN_COMPONENTS:-n/a}
boot_target=${OBOS_BOOT_TARGET}
output_format=${OBOS_OUTPUT_FORMAT}
output_compression=${OBOS_OUTPUT_COMPRESSION:-n/a}
image_extension=${OBOS_IMAGE_EXTENSION:-n/a}
image_min_size=${OBOS_IMAGE_MIN_SIZE:-n/a}
base_packages=${OBOS_BASE_PACKAGES}
rpi_boot_packages=${OBOS_RPI_BOOT_PACKAGES:-n/a}
provision_script=${OBOS_PROVISION_SCRIPT}
first_boot_service=${OBOS_FIRST_BOOT_SERVICE}
rpi_network_installer_compatible=${OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE:-false}
rpi_boot_media=${OBOS_RPI_BOOT_MEDIA:-n/a}
rpi_firmware_mode=${OBOS_RPI_FIRMWARE_MODE:-n/a}
rpi_partition_layout=${OBOS_RPI_PARTITION_LAYOUT:-n/a}
rpi_boot_partition_label=${OBOS_RPI_BOOT_PARTITION_LABEL:-n/a}
rpi_root_partition_label=${OBOS_RPI_ROOT_PARTITION_LABEL:-n/a}
rpi_required_tools=${OBOS_RPI_REQUIRED_TOOLS:-n/a}
kernel_required_config=${OBOS_KERNEL_REQUIRED_CONFIG:-n/a}
qcow2_base_image_url=${OBOS_QCOW2_BASE_IMAGE_URL:-n/a}
qcow2_min_size=${OBOS_QCOW2_MIN_SIZE:-n/a}
qcow2_builder=${OBOS_QCOW2_BUILDER:-n/a}
qcow2_required_tools=${OBOS_QCOW2_REQUIRED_TOOLS:-n/a}
default_ssh=${OBOS_IMAGE_DEFAULT_SSH:-n/a}
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

if [ "${OBOS_OUTPUT_FORMAT}" = "qcow2" ]; then
  cat <<EOF
qcow2_contract:
  - start from base image: ${OBOS_QCOW2_BASE_IMAGE_URL}
  - customize with: ${OBOS_QCOW2_BUILDER}
  - require tools: ${OBOS_QCOW2_REQUIRED_TOOLS}
  - resize image to at least: ${OBOS_QCOW2_MIN_SIZE}
  - keep SSH default: ${OBOS_IMAGE_DEFAULT_SSH}
EOF
fi

if [ "${OBOS_IMAGE_KIND}" = "rpi-image" ]; then
  cat <<EOF
rpi_contract:
  - image must be Raspberry Pi Network Installer compatible
  - image artifact must use extension: ${OBOS_IMAGE_EXTENSION}
  - image must be at least: ${OBOS_IMAGE_MIN_SIZE}
  - debootstrap components: ${OBOS_DEBIAN_COMPONENTS}
  - boot packages: ${OBOS_RPI_BOOT_PACKAGES}
  - image must boot from all declared media: ${OBOS_RPI_BOOT_MEDIA}
  - keep SSH default: ${OBOS_IMAGE_DEFAULT_SSH}
  - image must use partition layout: ${OBOS_RPI_PARTITION_LAYOUT}
  - boot partition label: ${OBOS_RPI_BOOT_PARTITION_LABEL}
  - root partition label: ${OBOS_RPI_ROOT_PARTITION_LABEL}
  - build host must provide tools: ${OBOS_RPI_REQUIRED_TOOLS}
  - kernel config must include: ${OBOS_KERNEL_REQUIRED_CONFIG}
EOF
fi
