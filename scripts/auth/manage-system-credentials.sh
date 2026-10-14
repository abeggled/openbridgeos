#!/usr/bin/env sh
set -eu

ACTION="${1:-ensure}"
OBOS_ETC_DIR="${OBOS_ETC_DIR:-/etc/obos}"
CREDENTIALS_FILE="${OBOS_SYSTEM_CREDENTIALS_FILE:-${OBOS_ETC_DIR}/system-credentials}"
PYTHON_BIN="${OBOS_PYTHON_BIN:-python3}"
GETENT="${OBOS_GETENT:-getent}"
USERADD="${OBOS_USERADD:-useradd}"
USERMOD="${OBOS_USERMOD:-usermod}"
CHPASSWD="${OBOS_CHPASSWD:-chpasswd}"
REQUIRE_ROOT="${OBOS_REQUIRE_ROOT:-1}"

fail() {
  echo "system credentials: $1" >&2
  exit 1
}

if [ "${REQUIRE_ROOT}" = 1 ] && [ "$(id -u)" -ne 0 ]; then
  fail "must run as root"
fi

case "${ACTION}" in
  ensure|rotate|show) ;;
  *) fail "usage: manage-system-credentials.sh [ensure|rotate|show]" ;;
esac

read_value() {
  key="$1"
  sed -n "s/^${key}=//p" "${CREDENTIALS_FILE}" | head -n 1
}

validate_password() {
  password="$1"
  [ "${#password}" -ge 20 ] || return 1
  printf '%s\n' "${password}" | grep -Eq '^[A-Za-z0-9_-]+$'
}

load_credentials() {
  [ -f "${CREDENTIALS_FILE}" ] || return 1
  [ "$(read_value format)" = obos-system-credentials-v1 ] || return 1
  root_password="$(read_value root_password)"
  obos_password="$(read_value obos_password)"
  validate_password "${root_password}" || return 1
  validate_password "${obos_password}" || return 1
}

generate_password() {
  "${PYTHON_BIN}" -c 'import secrets, string; alphabet = string.ascii_letters + string.digits + "_-"; print("".join(secrets.choice(alphabet) for _ in range(24)))'
}

stage_credentials() {
  install -d -m 0750 "${OBOS_ETC_DIR}"
  staged_credentials_file="${CREDENTIALS_FILE}.$$"
  umask 077
  cat > "${staged_credentials_file}" <<EOF
format=obos-system-credentials-v1
generated_at=$(date -u +%Y%m%dT%H%M%SZ)
root_password=${root_password}
obos_password=${obos_password}
EOF
  chmod 0600 "${staged_credentials_file}"
}

apply_accounts() {
  if ! "${GETENT}" passwd obos >/dev/null 2>&1; then
    "${USERADD}" --create-home --shell /bin/bash obos
  fi
  if "${GETENT}" group sudo >/dev/null 2>&1; then
    "${USERMOD}" --append --groups sudo obos
  fi
  printf 'root:%s\nobos:%s\n' "${root_password}" "${obos_password}" | "${CHPASSWD}"
}

credentials_created=false
staged_credentials_file=
trap '[ -n "${staged_credentials_file}" ] && rm -f "${staged_credentials_file}"' EXIT HUP INT TERM
if [ "${ACTION}" = show ]; then
  load_credentials || fail "credentials are not initialized"
else
  if [ "${ACTION}" = rotate ] || ! load_credentials; then
    root_password="$(generate_password)"
    obos_password="$(generate_password)"
    validate_password "${root_password}" || fail "generated root password is invalid"
    validate_password "${obos_password}" || fail "generated obos password is invalid"
    stage_credentials
    credentials_created=true
  fi
  if [ "${ACTION}" = rotate ] || [ "${credentials_created}" = true ] || ! "${GETENT}" passwd obos >/dev/null 2>&1; then
    apply_accounts
  fi
  if [ "${credentials_created}" = true ]; then
    mv -f "${staged_credentials_file}" "${CREDENTIALS_FILE}"
    staged_credentials_file=
  fi
fi

echo "format=obos-system-credentials-v1"
echo "mode=${ACTION}"
echo "root_password=${root_password}"
echo "obos_password=${obos_password}"

