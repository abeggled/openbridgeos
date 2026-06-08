#!/usr/bin/env sh
set -eu

IMAGE="${1:-}"
HOST_HTTPS_PORT="${OBOS_SMOKE_HOST_HTTPS_PORT:-8443}"
HOST_HTTP_PORT="${OBOS_SMOKE_HOST_HTTP_PORT:-18080}"
TIMEOUT_SECONDS="${OBOS_SMOKE_TIMEOUT_SECONDS:-900}"
MEMORY="${OBOS_SMOKE_MEMORY:-2048}"
CPUS="${OBOS_SMOKE_CPUS:-2}"
PID_FILE="${OBOS_SMOKE_PID_FILE:-}"
LOG_FILE="${OBOS_SMOKE_LOG_FILE:-}"
SNAPSHOT="${OBOS_SMOKE_SNAPSHOT:-on}"
REPORT_INTERVAL_SECONDS="${OBOS_SMOKE_REPORT_INTERVAL_SECONDS:-30}"

fail() {
  echo "amd64 qcow2 smoke test failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

[ -n "${IMAGE}" ] || fail "usage: scripts/images/smoke-test-amd64-qcow2.sh <image.qcow2>"
[ -f "${IMAGE}" ] || fail "image not found: ${IMAGE}"
case "${SNAPSHOT}" in
  on|off) ;;
  *) fail "OBOS_SMOKE_SNAPSHOT must be on or off" ;;
esac

require_command curl
require_command qemu-system-x86_64

if [ -z "${PID_FILE}" ]; then
  PID_FILE="$(mktemp)"
fi

if [ -z "${LOG_FILE}" ]; then
  LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/obos-qcow2-smoke.XXXXXX.log")"
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

echo "qcow2 smoke test: booting ${IMAGE}"
echo "qcow2 smoke test: log=${LOG_FILE}"
echo "qcow2 smoke test: https=https://127.0.0.1:${HOST_HTTPS_PORT}"
echo "qcow2 smoke test: direct-http=http://127.0.0.1:${HOST_HTTP_PORT}"
echo "qcow2 smoke test: memory=${MEMORY}MiB cpus=${CPUS} snapshot=${SNAPSHOT} timeout=${TIMEOUT_SECONDS}s"

qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -m "${MEMORY}" \
  -smp "${CPUS}" \
  -drive "file=${IMAGE},if=virtio,format=qcow2,snapshot=${SNAPSHOT}" \
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${HOST_HTTPS_PORT}-:443,hostfwd=tcp:127.0.0.1:${HOST_HTTP_PORT}-:8080" \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial mon:stdio \
  -display none \
  >"${LOG_FILE}" 2>&1 &

qemu_pid="$!"
printf '%s\n' "${qemu_pid}" > "${PID_FILE}"
echo "qcow2 smoke test: qemu-pid=${qemu_pid}"

start_time="$(date +%s)"
last_report="${start_time}"
https_proxy_ready=0
while :; do
  if ! kill -0 "${qemu_pid}" 2>/dev/null; then
    echo "last qemu log lines:" >&2
    tail -n 160 "${LOG_FILE}" >&2 || true
    fail "qemu exited before HTTPS health passed"
  fi

  if [ "${https_proxy_ready}" -eq 0 ]; then
    http_code="$(
      curl --insecure --silent --output /dev/null --write-out '%{http_code}' --max-time 5 \
        "https://127.0.0.1:${HOST_HTTPS_PORT}/obos/" 2>/dev/null || true
    )"
    case "${http_code}" in
      200|301|302|401|403)
        https_proxy_ready=1
        echo "qcow2 smoke test: HTTPS proxy is reachable with status ${http_code}"
        ;;
    esac
  fi

  if curl --insecure --fail --silent --max-time 5 \
    "https://127.0.0.1:${HOST_HTTPS_PORT}/api/v1/system/health" >/dev/null; then
    if curl --fail --silent --max-time 5 \
      "http://127.0.0.1:${HOST_HTTP_PORT}/api/v1/system/health" >/dev/null 2>&1; then
      fail "direct open bridge server HTTP is reachable from VM network boundary"
    fi
    echo "qcow2 smoke test: PASS"
    exit 0
  fi

  now="$(date +%s)"
  elapsed=$((now - start_time))
  if [ "${elapsed}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "last qemu log lines:" >&2
    tail -n 160 "${LOG_FILE}" >&2 || true
    fail "HTTPS health did not pass within ${TIMEOUT_SECONDS}s"
  fi
  since_report=$((now - last_report))
  if [ "${since_report}" -ge "${REPORT_INTERVAL_SECONDS}" ]; then
    if [ "${https_proxy_ready}" -eq 1 ]; then
      echo "qcow2 smoke test: waiting for open bridge server health (${elapsed}s elapsed)"
    else
      echo "qcow2 smoke test: waiting for HTTPS proxy (${elapsed}s elapsed)"
    fi
    last_report="${now}"
  fi

  sleep 5
done
