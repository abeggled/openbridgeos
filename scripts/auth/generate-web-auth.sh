#!/usr/bin/env sh
set -eu

OBOS_ETC_DIR="${OBOS_ETC_DIR:-/etc/obos}"
WEB_AUTH_FILE="${OBOS_WEB_AUTH_FILE:-${OBOS_ETC_DIR}/web.htpasswd}"
WEB_AUTH_INFO_FILE="${OBOS_WEB_AUTH_INFO_FILE:-${OBOS_ETC_DIR}/web-admin.env}"
WEB_AUTH_USER="${OBOS_WEB_AUTH_USER:-admin}"

if [ "$(id -u)" -ne 0 ]; then
  echo "generate-web-auth.sh must run as root" >&2
  exit 1
fi

secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
  else
    dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 | tr -d '\n'
  fi
}

hash_password() {
  password="$1"
  printf '%s\n' "${password}" | openssl passwd -apr1 -stdin
}

install -d -m 0750 "${OBOS_ETC_DIR}"

if [ -f "${WEB_AUTH_FILE}" ] && [ -f "${WEB_AUTH_INFO_FILE}" ]; then
  chmod 0640 "${WEB_AUTH_FILE}"
  chmod 0600 "${WEB_AUTH_INFO_FILE}"
  echo "web auth already exists: ${WEB_AUTH_FILE}"
  exit 0
fi

password="$(secret)"
password_hash="$(hash_password "${password}")"
tmp_auth="${WEB_AUTH_FILE}.tmp.$$"
tmp_info="${WEB_AUTH_INFO_FILE}.tmp.$$"

printf '%s:%s\n' "${WEB_AUTH_USER}" "${password_hash}" > "${tmp_auth}"
{
  echo "OBOS_WEB_ADMIN_USER=${WEB_AUTH_USER}"
  echo "OBOS_WEB_ADMIN_PASSWORD=${password}"
} > "${tmp_info}"

if getent group www-data >/dev/null 2>&1; then
  install -m 0640 -o root -g www-data "${tmp_auth}" "${WEB_AUTH_FILE}"
else
  install -m 0640 "${tmp_auth}" "${WEB_AUTH_FILE}"
fi
install -m 0600 "${tmp_info}" "${WEB_AUTH_INFO_FILE}"
rm -f "${tmp_auth}" "${tmp_info}"

cat <<EOF
Web console authentication generated.

User: ${WEB_AUTH_USER}
Password file: ${WEB_AUTH_FILE}
Credential record: ${WEB_AUTH_INFO_FILE}
EOF
