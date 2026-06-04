#!/usr/bin/env sh
set -eu

ENV_FILE="${OBOS_ENV_FILE:-/etc/obos/apps/openbridgeserver.env}"
NFT_FILE="${OBOS_NFT_FILE:-/etc/nftables.conf}"
SERVICE_NAME="${OBOS_SERVICE_NAME:-obos-openbridgeserver.service}"
NFTABLES_SERVICE="${OBOS_NFTABLES_SERVICE:-nftables.service}"

usage() {
  cat <<'EOF'
Usage: set-mqtt-lan-access.sh <enable [source-cidr]|disable|status>

Enables or disables explicit LAN access for MQTT plain TCP and MQTT WebSocket.
Default open bridge operating system installs keep both listeners bound to localhost.

When source-cidr is supplied, nftables allows MQTT only from that IPv4 or IPv6
source network, for example 192.168.1.0/24 or fd00::/64.
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

validate_source_cidr() {
  source_cidr="$1"
  [ -n "${source_cidr}" ] || return 0

  if printf '%s\n' "${source_cidr}" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$'; then
    return 0
  fi

  if printf '%s\n' "${source_cidr}" | grep -Eq '^[0-9A-Fa-f:]+/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])$'; then
    return 0
  fi

  echo "invalid MQTT source CIDR: ${source_cidr}" >&2
  exit 2
}

mqtt_rule_prefix() {
  source_cidr="$1"
  [ -n "${source_cidr}" ] || return 0

  case "${source_cidr}" in
    *:*)
      printf 'ip6 saddr %s ' "${source_cidr}"
      ;;
    *)
      printf 'ip saddr %s ' "${source_cidr}"
      ;;
  esac
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
  source_cidr="${2:-}"
  rule_prefix="$(mqtt_rule_prefix "${source_cidr}")"
  tmp="${NFT_FILE}.tmp.$$"

  awk -v mode="${mode}" -v rule_prefix="${rule_prefix}" '
    /# OBOS MQTT LAN BEGIN/ {
      print
      if (mode == "enable") {
        print "    " rule_prefix "tcp dport 1883 accept"
        print "    " rule_prefix "tcp dport 9001 accept"
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
  source_cidr="${1:-${OBOS_MQTT_LAN_SOURCE_CIDR:-}}"
  validate_source_cidr "${source_cidr}"
  require_file "${ENV_FILE}"
  require_file "${NFT_FILE}"
  set_env_value OBS_MQTT_HOST_PORT 0.0.0.0:1883
  set_env_value OBS_MQTT_WS_HOST_PORT 0.0.0.0:9001
  set_nft_mqtt_block enable "${source_cidr}"
  reload_firewall
  restart_app
  if [ -n "${source_cidr}" ]; then
    echo "MQTT LAN access enabled from ${source_cidr} on TCP 1883 and TCP 9001"
  else
    echo "MQTT LAN access enabled on TCP 1883 and TCP 9001"
  fi
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
    enable_lan "${2:-}"
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
