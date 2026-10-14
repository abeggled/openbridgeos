#!/usr/bin/env sh
set -eu

OBOS_ETC_DIR="${OBOS_ETC_DIR:-/etc/obos}"
OBOS_APP_DIR="${OBOS_APP_DIR:-/srv/obos/apps/openbridgeserver}"
OBOS_STATE_DIR="${OBOS_STATE_DIR:-/srv/obos/state}"
ENV_FILE="${OBOS_ETC_DIR}/apps/openbridgeserver.env"
APPLIANCE_ID_FILE="${OBOS_ETC_DIR}/appliance-id"
FIRST_BOOT_MARKER="${OBOS_STATE_DIR}/first-boot.done"
TLS_GENERATE_SCRIPT="${OBOS_TLS_GENERATE_SCRIPT:-/usr/lib/obos/generate-tls-material.sh}"
TLS_EXPORT_SCRIPT="${OBOS_TLS_EXPORT_SCRIPT:-/usr/lib/obos/export-trust-bundle.sh}"
BOOT_TRUST_SCRIPT="${OBOS_BOOT_TRUST_SCRIPT:-/usr/lib/obos/export-boot-trust-summary.sh}"
ONBOARDING_REQUIRED_FILE="${OBOS_ONBOARDING_REQUIRED_FILE:-${OBOS_STATE_DIR}/onboarding/onboarding-required}"
LEGACY_ONBOARDING_TOKEN_FILE="${OBOS_LEGACY_ONBOARDING_TOKEN_FILE:-${OBOS_STATE_DIR}/onboarding/setup-token}"
WEB_AUTH_FILE="${OBOS_WEB_AUTH_FILE:-${OBOS_ETC_DIR}/web.htpasswd}"
PENDING_NGINX_CONFIG="${OBOS_PENDING_NGINX_CONFIG:-${OBOS_ETC_DIR}/update/openbridgeserver.conf.pending}"
ACTIVE_NGINX_CONFIG="${OBOS_ACTIVE_NGINX_CONFIG:-/etc/nginx/sites-available/obos-openbridgeserver.conf}"
PREVIOUS_NGINX_CONFIG="${OBOS_PREVIOUS_NGINX_CONFIG:-${OBOS_ETC_DIR}/update/openbridgeserver.conf.previous}"
AGENT_HTTP_COMPAT_ENV="${OBOS_AGENT_HTTP_COMPAT_ENV:-${OBOS_ETC_DIR}/update/agent-http-compat.env}"
SYSTEM_CREDENTIALS_SCRIPT="${OBOS_SYSTEM_CREDENTIALS_SCRIPT:-/usr/lib/obos/manage-system-credentials.sh}"

secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n'
  else
    dd if=/dev/urandom bs=48 count=1 2>/dev/null | base64 | tr -d '\n'
  fi
}

uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  elif command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    openssl rand -hex 16 | sed 's/^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)$/\1-\2-\3-\4-\5/'
  fi
}

finalize_pending_nginx_config() {
  [ -s "${PENDING_NGINX_CONFIG}" ] || return 0
  install -d -m 0755 "$(dirname -- "${ACTIVE_NGINX_CONFIG}")"
  had_previous=false
  if [ -s "${PREVIOUS_NGINX_CONFIG}" ]; then
    had_previous=true
  elif [ -f "${ACTIVE_NGINX_CONFIG}" ]; then
    install -m 0644 "${ACTIVE_NGINX_CONFIG}" "${PREVIOUS_NGINX_CONFIG}"
    had_previous=true
  fi
  install -m 0644 "${PENDING_NGINX_CONFIG}" "${ACTIVE_NGINX_CONFIG}"
  if ! nginx -t; then
    if [ "${had_previous}" = true ]; then
      install -m 0644 "${PREVIOUS_NGINX_CONFIG}" "${ACTIVE_NGINX_CONFIG}"
    else
      rm -f "${ACTIVE_NGINX_CONFIG}"
    fi
    if [ "${had_previous}" = true ] && grep -Fq 'proxy_pass http://127.0.0.1:8091' "${ACTIVE_NGINX_CONFIG}"; then
      compat_tmp="$(mktemp "${AGENT_HTTP_COMPAT_ENV}.XXXXXX")"
      cat > "${compat_tmp}" <<'EOF'
OBOS_AGENT_HTTP_SOCKET=
OBOS_AGENT_HTTP_BIND=127.0.0.1
OBOS_AGENT_HTTP_PORT=8091
EOF
      chmod 0600 "${compat_tmp}"
      mv "${compat_tmp}" "${AGENT_HTTP_COMPAT_ENV}"
    else
      rm -f "${AGENT_HTTP_COMPAT_ENV}"
    fi
    echo "first boot: pending nginx configuration failed validation" >&2
    return 1
  fi
  rm -f "${PENDING_NGINX_CONFIG}" "${PREVIOUS_NGINX_CONFIG}" "${AGENT_HTTP_COMPAT_ENV}"
}

refresh_onboarding_window() {
  install -d -m 0700 -o obos-agent -g obos-agent "${OBOS_STATE_DIR}/onboarding"
  rm -f "${LEGACY_ONBOARDING_TOKEN_FILE}"
  python3 - "${ONBOARDING_REQUIRED_FILE}" <<'PY'
from datetime import datetime, timezone
import grp
import os
import pwd
import sys

owner_uid = pwd.getpwnam("obos-agent").pw_uid
owner_gid = grp.getgrnam("obos-agent").gr_gid


def replace_private_file(target, content):
    parent, name = os.path.split(target)
    directory = os.open(parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        try:
            os.unlink(name, dir_fd=directory)
        except FileNotFoundError:
            pass
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
        descriptor = os.open(name, flags, 0o600, dir_fd=directory)
        try:
            os.write(descriptor, content)
            os.fchmod(descriptor, 0o600)
            os.fchown(descriptor, owner_uid, owner_gid)
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    finally:
        os.close(directory)


created_at = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
required = (
    "format=obos-onboarding-required-v1\n"
    f"created_at={created_at}\n"
    "window_seconds=300\n"
    "window_basis=agent_start_per_boot_id\n"
).encode("ascii")
replace_private_file(sys.argv[1], required)
PY
}

finalize_pending_nginx_config

if [ ! -d "${OBOS_ETC_DIR}" ]; then
  install -d -m 0750 -o root -g www-data "${OBOS_ETC_DIR}"
else
  chmod 0750 "${OBOS_ETC_DIR}"
fi
if [ -x "${SYSTEM_CREDENTIALS_SCRIPT}" ]; then
  "${SYSTEM_CREDENTIALS_SCRIPT}" ensure >/dev/null
fi

if [ -f "${FIRST_BOOT_MARKER}" ]; then
  if [ ! -f "${WEB_AUTH_FILE}" ]; then
    refresh_onboarding_window
    if [ -x "${BOOT_TRUST_SCRIPT}" ]; then
      "${BOOT_TRUST_SCRIPT}"
    fi
  fi
  exit 0
fi

install -d -m 0750 "${OBOS_ETC_DIR}/apps" "${OBOS_STATE_DIR}"
install -d -m 0750 "${OBOS_APP_DIR}" "${OBOS_APP_DIR}/data" "${OBOS_APP_DIR}/mqtt"
install -d -m 0770 "${OBOS_APP_DIR}/mqtt/passwd" "${OBOS_APP_DIR}/mqtt/data" "${OBOS_APP_DIR}/mqtt/log"
install -d -m 0700 -o obos-agent -g obos-agent "${OBOS_STATE_DIR}/onboarding"

if [ ! -f "${APPLIANCE_ID_FILE}" ]; then
  uuid > "${APPLIANCE_ID_FILE}"
fi
chmod 0644 "${APPLIANCE_ID_FILE}"

if [ ! -f "${ENV_FILE}" ]; then
  umask 077
  cat > "${ENV_FILE}" <<EOF
OBS_HTTP_HOST_PORT=127.0.0.1:8080
OBS_MQTT_HOST_PORT=127.0.0.1:1883
OBS_MQTT_WS_HOST_PORT=127.0.0.1:9001
OBS_MQTT_USERNAME=obs
OBS_MQTT_PASSWORD=$(secret)
OBS_JWT_SECRET=$(secret)
OBS_LOG_LEVEL=INFO
EOF
fi

chmod 0600 "${ENV_FILE}"

if [ ! -f "${WEB_AUTH_FILE}" ]; then
  refresh_onboarding_window
fi

if [ -x "${TLS_GENERATE_SCRIPT}" ]; then
  "${TLS_GENERATE_SCRIPT}"
fi

if [ -x "${TLS_EXPORT_SCRIPT}" ]; then
  "${TLS_EXPORT_SCRIPT}"
fi

if [ -x "${BOOT_TRUST_SCRIPT}" ]; then
  "${BOOT_TRUST_SCRIPT}"
fi

marker_tmp="${FIRST_BOOT_MARKER}.$$"
cat > "${marker_tmp}" <<EOF
format=obos-first-boot-v1
completed_at=$(date -u +%Y%m%dT%H%M%SZ)
appliance_id=$(sed -n '1p' "${APPLIANCE_ID_FILE}")
app=openbridgeserver
EOF
install -m 0640 "${marker_tmp}" "${FIRST_BOOT_MARKER}"
rm -f "${marker_tmp}"
