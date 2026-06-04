#!/usr/bin/env sh
set -eu

IMAGE="${1:-}"
HOST_HTTPS_PORT="${OBOS_SMOKE_HOST_HTTPS_PORT:-8443}"
TIMEOUT_SECONDS="${OBOS_SMOKE_TIMEOUT_SECONDS:-900}"
MEMORY="${OBOS_SMOKE_MEMORY:-2048}"
CPUS="${OBOS_SMOKE_CPUS:-2}"
PID_FILE="${OBOS_SMOKE_PID_FILE:-}"

fail() {
  echo "amd64 qcow2 smoke test failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

[ -n "${IMAGE}" ] || fail "usage: scripts/images/smoke-test-amd64-qcow2.sh <image.qcow2>"
[ -f "${IMAGE}" ] || fail "image not found: ${IMAGE}"

require_command curl
require_command qemu-system-x86_64

if [ -z "${PID_FILE}" ]; then
  PID_FILE="$(mktemp)"
fi

cleanup() {
  if [ -f "${PID_FILE}" ]; then
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}"
  fi
}
trap cleanup EXIT INT TERM

qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -m "${MEMORY}" \
  -smp "${CPUS}" \
  -drive "file=${IMAGE},if=virtio,format=qcow2,snapshot=on" \
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${HOST_HTTPS_PORT}-:443" \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial mon:stdio \
  -display none \
  >/tmp/obos-qcow2-smoke.log 2>&1 &

qemu_pid="$!"
printf '%s\n' "${qemu_pid}" > "${PID_FILE}"

start_time="$(date +%s)"
while :; do
  if curl --insecure --fail --silent --show-error --max-time 5 \
    "https://127.0.0.1:${HOST_HTTPS_PORT}/api/v1/system/health" >/dev/null; then
    echo "qcow2 smoke test: PASS"
    exit 0
  fi

  now="$(date +%s)"
  elapsed=$((now - start_time))
  if [ "${elapsed}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "last qemu log lines:" >&2
    tail -n 80 /tmp/obos-qcow2-smoke.log >&2 || true
    fail "HTTPS health did not pass within ${TIMEOUT_SECONDS}s"
  fi

  sleep 5
done
