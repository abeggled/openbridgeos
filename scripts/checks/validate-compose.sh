#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${1:-apps/openbridgeserver/compose.yaml}"

export OBS_MQTT_PASSWORD="${OBS_MQTT_PASSWORD:-dummy-mqtt-password-for-validation}"
export OBS_JWT_SECRET="${OBS_JWT_SECRET:-dummy-jwt-secret-for-validation-with-enough-length}"

docker compose -f "${COMPOSE_FILE}" config >/dev/null
