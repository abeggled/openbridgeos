#!/usr/bin/env sh
set -eu

ENV_FILE="${OBOS_ENV_FILE:-/etc/obos/apps/openbridgeserver.env}"
NFT_FILE="${OBOS_NFT_FILE:-/etc/nftables.conf}"
SERVICE_NAME="${OBOS_SERVICE_NAME:-obos-openbridgeserver.service}"
NFTABLES_SERVICE="${OBOS_NFTABLES_SERVICE:-nftables.service}"

usage() {
  cat <<'EOF'
Usage: set-mqtt-lan-access.sh <enable|disable|status>

Enables or disables explicit LAN access for MQTT plain TCP and MQTT WebSocket.
Default Open Bridge OS installs keep both listeners bound to localhost.
EOF
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "set-mqtt-lan-access.sh must run as root" >&2
    exit 1
  fi
}

require_file() {
  path="$1"
  [ -f "${path}" ] || {
    echo "missing required file: ${path}" >&2
    exit 1
  }
}

set_env_value() {
  key="$1"
  value="$2"
  tmp="${ENV_FILE}.tmp.$$"

  if grep -q "^${key}=" "${ENV_FILE}"; then
    sed "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}" > "${tmp}"
  else
    cp "${ENV_FILE}" "${tmp}"
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
  fi

  install -m 0600 "${tmp}" "${ENV_FILE}"
  rm -f "${tmp}"
}

set_nft_mqtt_block() {
  mode="$1"
  tmp="${NFT_FILE}.tmp.$$"

  awk -v mode="${mode}" '
    /# OBOS MQTT LAN BEGIN/ {
      print
      if (mode == "enable") {
        print "    tcp dport 1883 accept"
        print "    tcp dport 9001 accept"
      } else {
        print "    # MQTT LAN disabled by default."
      }
      skip = 1
      next
    }
    /# OBOS MQTT LAN END/ {
      skip = 0
      print
      next
    }
    skip == 1 { next }
    { print }
  ' "${NFT_FILE}" > "${tmp}"

  install -m 0644 "${tmp}" "${NFT_FILE}"
  rm -f "${tmp}"
}

reload_firewall() {
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files "${NFTABLES_SERVICE}" >/dev/null 2>&1; then
    systemctl restart "${NFTABLES_SERVICE}"
  elif command -v nft >/dev/null 2>&1; then
    nft -f "${NFT_FILE}"
  fi
}

restart_app() {
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files "${SERVICE_NAME}" >/dev/null 2>&1; then
    systemctl restart "${SERVICE_NAME}"
  fi
}

status() {
  require_file "${ENV_FILE}"
  grep -E '^(OBS_MQTT_HOST_PORT|OBS_MQTT_WS_HOST_PORT)=' "${ENV_FILE}" || true
}

enable_lan() {
  require_file "${ENV_FILE}"
  require_file "${NFT_FILE}"
  set_env_value OBS_MQTT_HOST_PORT 0.0.0.0:1883
  set_env_value OBS_MQTT_WS_HOST_PORT 0.0.0.0:9001
  set_nft_mqtt_block enable
  reload_firewall
  restart_app
  echo "MQTT LAN access enabled on TCP 1883 and TCP 9001"
}

disable_lan() {
  require_file "${ENV_FILE}"
  require_file "${NFT_FILE}"
  set_env_value OBS_MQTT_HOST_PORT 127.0.0.1:1883
  set_env_value OBS_MQTT_WS_HOST_PORT 127.0.0.1:9001
  set_nft_mqtt_block disable
  reload_firewall
  restart_app
  echo "MQTT LAN access disabled; listeners are localhost-only"
}

require_root

case "${1:-}" in
  enable)
    enable_lan
    ;;
  disable)
    disable_lan
    ;;
  status)
    status
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
