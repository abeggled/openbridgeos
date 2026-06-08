#!/usr/bin/env sh
set -eu

PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/rpi4-arm64.env}"

fail() {
  echo "Raspberry Pi kernel config check failed: $1" >&2
  exit 1
}

pass() {
  printf 'PASS %s\n' "$1"
}

find_kernel_config() {
  target="$1"

  if [ -f "${target}" ]; then
    printf '%s\n' "${target}"
    return 0
  fi

  for candidate in \
    "${target}/boot/config-"* \
    "${target}/boot/config" \
    "${target}/proc/config.gz"; do
    if [ -f "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

config_is_active() {
  config_file="$1"
  expected="$2"
  key="${expected%%=*}"

  if grep -q "^${key}=y$" "${config_file}"; then
    return 0
  fi

  if grep -q "^${key}=m$" "${config_file}"; then
    return 0
  fi

  return 1
}

check_required_config() {
  config_file="$1"
  values="$2"

  old_ifs="${IFS}"
  IFS=,
  # shellcheck disable=SC2086
  set -- ${values}
  IFS="${old_ifs}"

  for expected in "$@"; do
    if config_is_active "${config_file}" "${expected}"; then
      pass "${expected}"
    else
      fail "missing required active kernel config: ${expected}"
    fi
  done
}

[ "$#" -eq 1 ] || fail "usage: $0 <kernel-config-file-or-mounted-root>"
TARGET="$1"

[ -f "${PROFILE_FILE}" ] || fail "missing image profile: ${PROFILE_FILE}"

OBOS_IMAGE_PROFILE=
OBOS_IMAGE_KIND=
OBOS_KERNEL_REQUIRED_CONFIG=

# shellcheck disable=SC1090
. "${PROFILE_FILE}"

[ "${OBOS_IMAGE_PROFILE}" = "rpi4-arm64" ] || fail "profile must be rpi4-arm64"
[ "${OBOS_IMAGE_KIND}" = "rpi-image" ] || fail "profile must describe a Raspberry Pi image"
[ -n "${OBOS_KERNEL_REQUIRED_CONFIG}" ] || fail "profile must define OBOS_KERNEL_REQUIRED_CONFIG"

CONFIG_FILE="$(find_kernel_config "${TARGET}")" \
  || fail "kernel config not found in ${TARGET}"

case "${CONFIG_FILE}" in
  *.gz) fail "compressed kernel configs are not supported yet: ${CONFIG_FILE}" ;;
  */boot/config.txt) fail "Raspberry Pi firmware config is not a Linux kernel config: ${CONFIG_FILE}" ;;
esac

check_required_config "${CONFIG_FILE}" "${OBOS_KERNEL_REQUIRED_CONFIG}"

echo "Raspberry Pi kernel config: PASS ${CONFIG_FILE}"
