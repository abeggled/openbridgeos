#!/usr/bin/env sh
set -u

FAILED=0
PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/amd64-vm.env}"

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

if [ -f "${PROFILE_FILE}" ]; then
  pass "image profile found: ${PROFILE_FILE}"
else
  fail "image profile missing: ${PROFILE_FILE}"
fi

if [ -x scripts/images/validate-image-profiles.sh ]; then
  if sh scripts/images/validate-image-profiles.sh "${PROFILE_FILE}" >/dev/null 2>&1; then
    pass "image profile validates"
  else
    fail "image profile validation failed"
  fi
else
  fail "image profile validator missing or not executable"
fi

check_command qemu-img
check_command virt-customize
check_command virt-sysprep
check_command sha256sum
check_command curl
check_optional_command qemu-system-x86_64

if [ -c /dev/kvm ]; then
  pass "/dev/kvm available"
else
  warn "/dev/kvm unavailable; qemu smoke tests may fall back to slow emulation"
fi

if command -v virt-customize >/dev/null 2>&1; then
  if virt-customize --version >/dev/null 2>&1; then
    pass "virt-customize responds"
  else
    fail "virt-customize does not respond"
  fi
fi

if command -v qemu-img >/dev/null 2>&1; then
  if qemu-img --version >/dev/null 2>&1; then
    pass "qemu-img responds"
  else
    fail "qemu-img does not respond"
  fi
fi

if [ "${FAILED}" -eq 0 ]; then
  echo "amd64 qcow2 build host: PASS"
else
  echo "amd64 qcow2 build host: FAIL"
fi

exit "${FAILED}"
