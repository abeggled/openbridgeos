#!/usr/bin/env sh
set -u

FAILED=0
PROFILE_FILE="${OBOS_IMAGE_PROFILE_FILE:-packaging/images/profiles/amd64-installer.env}"

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 installed"
  else
    fail "$1 missing"
  fi
}

if [ -f "${PROFILE_FILE}" ]; then
  pass "image profile found: ${PROFILE_FILE}"
else
  fail "image profile missing: ${PROFILE_FILE}"
fi

if sh scripts/images/validate-image-profiles.sh "${PROFILE_FILE}" >/dev/null 2>&1; then
  pass "image profile validates"
else
  fail "image profile validation failed"
fi

check_command lb
check_command xorriso
check_command sha256sum

if [ "$(id -u)" -eq 0 ]; then
  pass "running as root"
else
  fail "live-build requires root"
fi

if [ "${FAILED}" -eq 0 ]; then
  echo "amd64 installer ISO build host: PASS"
else
  echo "amd64 installer ISO build host: FAIL"
fi
exit "${FAILED}"
