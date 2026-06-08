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
WEB_AUTH_FILE="${OBOS_WEB_AUTH_FILE:-${OBOS_ETC_DIR}/web.htpasswd}"

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

refresh_onboarding_window() {
  now_epoch="$(date +%s)"
  expires_epoch=$((now_epoch + 300))
  install -d -m 0700 -o obos-agent -g obos-agent "${OBOS_STATE_DIR}/onboarding"
  {
    echo "format=obos-onboarding-required-v1"
    echo "created_at=$(date -u +%Y%m%dT%H%M%SZ)"
    echo "expires_at_epoch=${expires_epoch}"
    echo "window_seconds=300"
  } > "${ONBOARDING_REQUIRED_FILE}"
  chown obos-agent:obos-agent "${ONBOARDING_REQUIRED_FILE}" 2>/dev/null || true
  chmod 0600 "${ONBOARDING_REQUIRED_FILE}"
}

if [ -f "${FIRST_BOOT_MARKER}" ]; then
  if [ ! -f "${WEB_AUTH_FILE}" ]; then
    refresh_onboarding_window
  fi
  exit 0
fi

install -d -m 0750 "${OBOS_ETC_DIR}" "${OBOS_ETC_DIR}/apps" "${OBOS_STATE_DIR}"
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
OBS_IMAGE_TAG=latest
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
