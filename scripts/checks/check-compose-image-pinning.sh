#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CHECKER="scripts/images/check-compose-image-pinning.sh"

fail() {
  echo "compose image pinning fixture failed: $1" >&2
  exit 1
}

sh "${CHECKER}" apps/openbridgeserver/compose.yaml | grep -q '^format=obos-compose-image-pinning-v1$' \
  || fail "real compose pinning check did not print format"

cat > "${TMP_DIR}/pinned.yaml" <<'EOF'
services:
  mosquitto:
    image: eclipse-mosquitto@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  obs:
    image: ghcr.io/abeggled/openbridgeserver@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
EOF

OBOS_REQUIRE_PINNED_IMAGES=1 sh "${CHECKER}" "${TMP_DIR}/pinned.yaml" |
  grep -q '^result=PASS$' \
  || fail "strict pinned compose did not pass"

cat > "${TMP_DIR}/unpinned.yaml" <<'EOF'
services:
  obs:
    image: ghcr.io/abeggled/openbridgeserver:latest
EOF

if OBOS_REQUIRE_PINNED_IMAGES=1 sh "${CHECKER}" "${TMP_DIR}/unpinned.yaml" >/dev/null 2>&1; then
  fail "strict unpinned compose was accepted"
fi

echo "compose image pinning fixture: PASS"
