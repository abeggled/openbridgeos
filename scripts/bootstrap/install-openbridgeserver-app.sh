#!/usr/bin/env sh
set -eu

SOURCE_DIR="${1:-/usr/share/obos/apps/openbridgeserver}"
TARGET_DIR="${OBOS_APP_DIR:-/srv/obos/apps/openbridgeserver}"

install -d -m 0750 "${TARGET_DIR}"
install -d -m 0750 "${TARGET_DIR}/data" "${TARGET_DIR}/mqtt"
install -d -m 0770 "${TARGET_DIR}/mqtt/passwd" "${TARGET_DIR}/mqtt/data" "${TARGET_DIR}/mqtt/log"

install -m 0644 "${SOURCE_DIR}/compose.yaml" "${TARGET_DIR}/compose.yaml"
install -m 0644 "${SOURCE_DIR}/mosquitto.conf" "${TARGET_DIR}/mosquitto.conf"
install -m 0644 "${SOURCE_DIR}/obos-app.yaml" "${TARGET_DIR}/obos-app.yaml"
