#!/usr/bin/env sh
set -eu

HELPER="scripts/auth/manage-system-credentials.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  echo "system credentials check failed: $1" >&2
  exit 1
}

mkdir -p "${TMP_DIR}/bin" "${TMP_DIR}/etc"
cat > "${TMP_DIR}/bin/getent" <<EOF
#!/bin/sh
if [ "\${1:-}" = group ] && [ "\${2:-}" = sudo ]; then exit 0; fi
if [ "\${1:-}" = passwd ] && [ "\${2:-}" = obos ] && [ -f "${TMP_DIR}/user-created" ]; then exit 0; fi
exit 2
EOF
cat > "${TMP_DIR}/bin/useradd" <<EOF
#!/bin/sh
: > "${TMP_DIR}/user-created"
EOF
cat > "${TMP_DIR}/bin/usermod" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "${TMP_DIR}/usermod.log"
EOF
cat > "${TMP_DIR}/bin/chpasswd" <<EOF
#!/bin/sh
cat >> "${TMP_DIR}/chpasswd.log"
EOF
chmod 0755 "${TMP_DIR}/bin/getent" "${TMP_DIR}/bin/useradd" "${TMP_DIR}/bin/usermod" "${TMP_DIR}/bin/chpasswd"

run_helper() {
  OBOS_REQUIRE_ROOT=0 \
  OBOS_ETC_DIR="${TMP_DIR}/etc" \
  OBOS_SYSTEM_CREDENTIALS_FILE="${TMP_DIR}/etc/system-credentials" \
  OBOS_GETENT="${TMP_DIR}/bin/getent" \
  OBOS_USERADD="${TMP_DIR}/bin/useradd" \
  OBOS_USERMOD="${TMP_DIR}/bin/usermod" \
  OBOS_CHPASSWD="${TMP_DIR}/bin/chpasswd" \
  sh "${HELPER}" "$1"
}

first_output="$(run_helper ensure)"
[ "$(stat -c '%a' "${TMP_DIR}/etc/system-credentials")" = 600 ] \
  || fail "credentials file is not mode 0600"
root_password="$(printf '%s\n' "${first_output}" | sed -n 's/^root_password=//p')"
obos_password="$(printf '%s\n' "${first_output}" | sed -n 's/^obos_password=//p')"
[ "${root_password}" != "${obos_password}" ] || fail "root and obos passwords are identical"
printf '%s\n' "${root_password}" | grep -Eq '^[A-Za-z0-9_-]{20,}$' \
  || fail "root password format is invalid"
printf '%s\n' "${obos_password}" | grep -Eq '^[A-Za-z0-9_-]{20,}$' \
  || fail "obos password format is invalid"
[ "$(wc -l < "${TMP_DIR}/chpasswd.log")" -eq 2 ] \
  || fail "initial account passwords were not applied exactly once"

second_output="$(run_helper ensure)"
[ "$(printf '%s\n' "${second_output}" | sed -n 's/^root_password=//p')" = "${root_password}" ] \
  || fail "ensure unexpectedly rotated credentials"
[ "$(wc -l < "${TMP_DIR}/chpasswd.log")" -eq 2 ] \
  || fail "ensure reapplied initialized passwords"

rotated_output="$(run_helper rotate)"
[ "$(printf '%s\n' "${rotated_output}" | sed -n 's/^root_password=//p')" != "${root_password}" ] \
  || fail "rotation did not replace the root password"
[ "$(wc -l < "${TMP_DIR}/chpasswd.log")" -eq 4 ] \
  || fail "rotation did not apply both account passwords"

show_output="$(run_helper show)"
printf '%s\n' "${show_output}" | grep -Fq 'mode=show' \
  || fail "show action did not return credentials"

mkdir -p "${TMP_DIR}/second-etc"
second_install_output="$(
  OBOS_REQUIRE_ROOT=0 \
  OBOS_ETC_DIR="${TMP_DIR}/second-etc" \
  OBOS_SYSTEM_CREDENTIALS_FILE="${TMP_DIR}/second-etc/system-credentials" \
  OBOS_GETENT="${TMP_DIR}/bin/getent" \
  OBOS_USERADD="${TMP_DIR}/bin/useradd" \
  OBOS_USERMOD="${TMP_DIR}/bin/usermod" \
  OBOS_CHPASSWD="${TMP_DIR}/bin/chpasswd" \
  sh "${HELPER}" ensure
)"
[ "$(printf '%s\n' "${second_install_output}" | sed -n 's/^root_password=//p')" != "${root_password}" ] \
  || fail "two installations generated the same root password"
[ "$(printf '%s\n' "${second_install_output}" | sed -n 's/^obos_password=//p')" != "${obos_password}" ] \
  || fail "two installations generated the same obos password"

echo "system credentials check: PASS"

