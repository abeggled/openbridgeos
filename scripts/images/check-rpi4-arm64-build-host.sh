#!/usr/bin/env sh
set -u

FAILED=0
PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/rpi4-arm64.env}"
VALIDATE_IMAGE_PROFILES="scripts/images/validate-image-profiles.sh"

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1"
  FAILED=1
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    fail "$1 missing"
  fi
}

check_optional_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    warn "$1 missing"
  fi
}

check_root() {
  if command -v id >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      pass "running as root"
    else
      warn "not running as root; raw image partitioning and filesystem creation require root"
    fi
  else
    warn "id command missing; root status not checked"
  fi
}

check_binfmt() {
  if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    pass "qemu-aarch64 binfmt registered"
  else
    warn "qemu-aarch64 binfmt not registered; arm64 chroot commands may fail"
  fi
}

check_loop_support() {
  if [ -e /dev/loop-control ]; then
    pass "/dev/loop-control available"
  else
    warn "/dev/loop-control unavailable; image partition mounting may fail"
  fi
}

check_profile_tools() {
  old_ifs="${IFS}"
  IFS=,
  set -- ${OBOS_RPI_REQUIRED_TOOLS}
  IFS="${old_ifs}"

  for tool in "$@"; do
    check_command "${tool}"
  done
}

if [ -f "${PROFILE_FILE}" ]; then
  pass "image profile found: ${PROFILE_FILE}"
else
  fail "image profile missing: ${PROFILE_FILE}"
fi

if [ -f "${VALIDATE_IMAGE_PROFILES}" ]; then
  if sh "${VALIDATE_IMAGE_PROFILES}" "${PROFILE_FILE}" >/dev/null 2>&1; then
    pass "image profile validates"
  else
    fail "image profile validation failed"
  fi
else
  fail "image profile validator missing"
fi

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_ARCH=
OBOS_IMAGE_KIND=
OBOS_OUTPUT_FORMAT=
OBOS_OUTPUT_COMPRESSION=
OBOS_IMAGE_EXTENSION=
OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE=
OBOS_RPI_BOOT_MEDIA=
OBOS_RPI_PARTITION_LAYOUT=
OBOS_RPI_REQUIRED_TOOLS=
OBOS_KERNEL_REQUIRED_CONFIG=

if [ -f "${PROFILE_FILE}" ]; then
  # shellcheck disable=SC1090
  . "${PROFILE_FILE}"
fi

if [ "${OBOS_IMAGE_PROFILE}" = "rpi4-arm64" ]; then
  pass "profile is rpi4-arm64"
else
  fail "profile must be rpi4-arm64"
fi

if [ "${OBOS_IMAGE_ARCH}" = "arm64" ]; then
  pass "architecture is arm64"
else
  fail "architecture must be arm64"
fi

if [ "${OBOS_OUTPUT_FORMAT}" = "raw" ] && [ "${OBOS_OUTPUT_COMPRESSION}" = "xz" ] && [ "${OBOS_IMAGE_EXTENSION}" = "img.xz" ]; then
  pass "artifact format is raw img.xz"
else
  fail "artifact format must be raw img.xz"
fi

check_profile_tools
check_optional_command losetup
check_optional_command mount
check_optional_command umount
check_optional_command partprobe
check_root
check_binfmt
check_loop_support

if [ "${FAILED}" -eq 0 ]; then
  echo "Raspberry Pi arm64 build host: PASS"
else
  echo "Raspberry Pi arm64 build host: FAIL"
fi

exit "${FAILED}"
