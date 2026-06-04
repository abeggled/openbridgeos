#!/usr/bin/env sh
set -eu

fail() {
  echo "image profile validation failed: $1" >&2
  exit 1
}

validate_profile() {
  profile_file="$1"
  [ -f "${profile_file}" ] || fail "missing profile: ${profile_file}"

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

  [ -n "${OBOS_IMAGE_PROFILE}" ] || fail "${profile_file}: OBOS_IMAGE_PROFILE missing"
  [ -n "${OBOS_IMAGE_ARCH}" ] || fail "${profile_file}: OBOS_IMAGE_ARCH missing"
  [ -n "${OBOS_IMAGE_KIND}" ] || fail "${profile_file}: OBOS_IMAGE_KIND missing"
  [ -n "${OBOS_DEBIAN_RELEASE}" ] || fail "${profile_file}: OBOS_DEBIAN_RELEASE missing"
  [ -n "${OBOS_BOOT_TARGET}" ] || fail "${profile_file}: OBOS_BOOT_TARGET missing"
  [ -n "${OBOS_OUTPUT_FORMAT}" ] || fail "${profile_file}: OBOS_OUTPUT_FORMAT missing"
  [ -n "${OBOS_BASE_PACKAGES}" ] || fail "${profile_file}: OBOS_BASE_PACKAGES missing"
  [ -n "${OBOS_PROVISION_SCRIPT}" ] || fail "${profile_file}: OBOS_PROVISION_SCRIPT missing"
  [ -n "${OBOS_FIRST_BOOT_SERVICE}" ] || fail "${profile_file}: OBOS_FIRST_BOOT_SERVICE missing"

  case "${OBOS_IMAGE_ARCH}" in
    amd64|arm64) ;;
    *) fail "${profile_file}: unsupported architecture ${OBOS_IMAGE_ARCH}" ;;
  esac

  case "${OBOS_IMAGE_KIND}" in
    vm-image|installer-iso|rpi-image) ;;
    *) fail "${profile_file}: unsupported image kind ${OBOS_IMAGE_KIND}" ;;
  esac

  case "${OBOS_DEBIAN_RELEASE}" in
    trixie) ;;
    *) fail "${profile_file}: unsupported Debian release ${OBOS_DEBIAN_RELEASE}" ;;
  esac

  case "${OBOS_OUTPUT_FORMAT}" in
    qcow2|raw|iso) ;;
    *) fail "${profile_file}: unsupported output format ${OBOS_OUTPUT_FORMAT}" ;;
  esac

  [ "${OBOS_PROVISION_SCRIPT}" = "scripts/bootstrap/provision-debian.sh" ] \
    || fail "${profile_file}: image profile must use the shared Debian provisioner"
  [ "${OBOS_FIRST_BOOT_SERVICE}" = "obos-first-boot.service" ] \
    || fail "${profile_file}: first boot service must remain obos-first-boot.service"

  echo "PASS ${profile_file}"
}

if [ "$#" -eq 0 ]; then
  set -- packaging/images/profiles/*.env
fi

for profile in "$@"; do
  validate_profile "${profile}"
done
