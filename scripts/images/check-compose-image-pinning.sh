#!/usr/bin/env sh
set -eu

compose_file="${1:-apps/openbridgeserver/compose.yaml}"
require_pinned="${OBOS_REQUIRE_PINNED_IMAGES:-0}"

fail() {
  echo "compose image pinning check failed: $1" >&2
  exit 1
}

[ -f "${compose_file}" ] || fail "compose file not found: ${compose_file}"

case "${require_pinned}" in
  0|1) ;;
  *) fail "OBOS_REQUIRE_PINNED_IMAGES must be 0 or 1" ;;
esac

image_count=0
pinned_count=0
unpinned_count=0

echo "format=obos-compose-image-pinning-v1"
echo "compose_file=${compose_file}"
echo "require_pinned=${require_pinned}"

while IFS= read -r image; do
  [ -n "${image}" ] || continue
  image_count=$((image_count + 1))
  case "${image}" in
    *@sha256:*)
      pinned=true
      pinned_count=$((pinned_count + 1))
      ;;
    *)
      pinned=false
      unpinned_count=$((unpinned_count + 1))
      ;;
  esac
  echo "image=${image}|pinned=${pinned}"
done <<EOF
$(awk '
  /^[[:space:]]*image:[[:space:]]*/ {
    sub(/^[[:space:]]*image:[[:space:]]*/, "")
    gsub(/^["'\'']|["'\'']$/, "")
    print
  }
' "${compose_file}")
EOF

[ "${image_count}" -gt 0 ] || fail "no compose images found"

echo "image_count=${image_count}"
echo "pinned_count=${pinned_count}"
echo "unpinned_count=${unpinned_count}"

if [ "${require_pinned}" = "1" ] && [ "${unpinned_count}" -gt 0 ]; then
  fail "unpinned images found"
fi

echo "result=PASS"
