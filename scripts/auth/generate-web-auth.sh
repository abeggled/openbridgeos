#!/usr/bin/env sh
set -eu

OBOS_ETC_DIR="${OBOS_ETC_DIR:-/etc/obos}"
WEB_AUTH_FILE="${OBOS_WEB_AUTH_FILE:-${OBOS_ETC_DIR}/web.htpasswd}"
WEB_AUTH_INFO_FILE="${OBOS_WEB_AUTH_INFO_FILE:-${OBOS_ETC_DIR}/web-admin.env}"
ONBOARDING_REQUIRED_FILE="${OBOS_ONBOARDING_REQUIRED_FILE:-/srv/obos/state/onboarding/onboarding-required}"
WEB_AUTH_USER="${OBOS_WEB_AUTH_USER:-admin}"
MODE="${1:-generate}"
PASSWORD_FILE="${2:-}"

if [ "$(id -u)" -ne 0 ]; then
  echo "generate-web-auth.sh must run as root" >&2
  exit 1
fi

case "${MODE}" in
  generate|rotate|set) ;;
  -h|--help|help)
    echo "usage: generate-web-auth.sh [generate|rotate|set <password-file>]" >&2
    exit 2
    ;;
  *)
    echo "generate-web-auth.sh: unsupported mode: ${MODE}" >&2
    exit 2
    ;;
esac

secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
  else
    dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 | tr -d '\n'
  fi
}

read_password_file() {
  [ -n "${PASSWORD_FILE}" ] || {
    echo "generate-web-auth.sh set requires a password file" >&2
    exit 2
  }
  [ -f "${PASSWORD_FILE}" ] || {
    echo "generate-web-auth.sh password file missing: ${PASSWORD_FILE}" >&2
    exit 2
  }
  password="$(sed -n '1p' "${PASSWORD_FILE}")"
  [ -n "${password}" ] || {
    echo "generate-web-auth.sh password must not be empty" >&2
    exit 2
  }
  [ "${#password}" -ge 12 ] || {
    echo "generate-web-auth.sh password must be at least 12 characters" >&2
    exit 2
  }
  printf '%s\n' "${password}"
}

hash_password() {
  password="$1"
  printf '%s\n' "${password}" | openssl passwd -6 -stdin
}

write_info_record() {
  tmp_info="${WEB_AUTH_INFO_FILE}.tmp.$$"
  {
    echo "format=obos-web-auth-info-v2"
    echo "OBOS_WEB_ADMIN_USER=${WEB_AUTH_USER}"
    echo "password_storage=hash-only"
    echo "updated_at=$(date -u +%Y%m%dT%H%M%SZ)"
  } > "${tmp_info}"
  install -m 0600 "${tmp_info}" "${WEB_AUTH_INFO_FILE}"
  rm -f "${tmp_info}"
}

install_password_hash() {
  password_hash="$1"
  tmp_auth="${WEB_AUTH_FILE}.tmp.$$"
  printf '%s:%s\n' "${WEB_AUTH_USER}" "${password_hash}" > "${tmp_auth}"
  if getent group www-data >/dev/null 2>&1; then
    install -m 0640 -o root -g www-data "${tmp_auth}" "${WEB_AUTH_FILE}"
  else
    install -m 0640 "${tmp_auth}" "${WEB_AUTH_FILE}"
  fi
  rm -f "${tmp_auth}"
}

install -d -m 0750 -o root -g www-data "${OBOS_ETC_DIR}"

if [ "${MODE}" = generate ] && [ -f "${WEB_AUTH_FILE}" ]; then
  legacy_password="$(sed -n 's/^OBOS_WEB_ADMIN_PASSWORD=//p' "${WEB_AUTH_INFO_FILE}" 2>/dev/null | head -n 1)"
  if [ -n "${legacy_password}" ]; then
    install_password_hash "$(hash_password "${legacy_password}")"
    unset legacy_password
  else
    chmod 0640 "${WEB_AUTH_FILE}"
  fi
  write_info_record
  echo "web auth already exists: ${WEB_AUTH_FILE}"
  exit 0
fi

if [ "${MODE}" = set ]; then
  password="$(read_password_file)"
else
  password="$(secret)"
fi
password_hash="$(hash_password "${password}")"
install_password_hash "${password_hash}"
write_info_record

cat <<EOF
Web console authentication generated.

format=obos-web-auth-v1
mode=${MODE}
User: ${WEB_AUTH_USER}
Password file: ${WEB_AUTH_FILE}
Credential record: ${WEB_AUTH_INFO_FILE}
EOF

if [ "${MODE}" = rotate ]; then
  cat <<EOF
password=${password}
web auth rotate: PASS
EOF
fi

if [ "${MODE}" = set ]; then
  rm -f "${ONBOARDING_REQUIRED_FILE}"
  cat <<'EOF'
web auth set: PASS
EOF
fi
