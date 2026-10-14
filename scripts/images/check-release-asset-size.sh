#!/usr/bin/env sh
set -eu

MAX_BYTES="${OBOS_RELEASE_ASSET_MAX_BYTES:-2147483647}"

fail() {
  echo "release asset size check failed: $1" >&2
  exit 1
}

case "${MAX_BYTES}" in ''|*[!0-9]*) fail "OBOS_RELEASE_ASSET_MAX_BYTES must be a positive integer" ;; 0) fail "maximum must be greater than zero" ;; esac
[ "$#" -gt 0 ] || fail "usage: $0 <asset> [asset...]"

for asset in "$@"; do
  [ -f "${asset}" ] || fail "asset missing: ${asset}"
  size="$(wc -c < "${asset}" | tr -d ' ')"
  [ "${size}" -le "${MAX_BYTES}" ] || fail "${asset} is ${size} bytes; GitHub limit is ${MAX_BYTES} bytes"
  printf 'PASS %s bytes=%s\n' "${asset}" "${size}"
done
