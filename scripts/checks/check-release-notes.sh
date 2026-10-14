#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
EXTRACT_NOTES="${ROOT_DIR}/scripts/update/extract-release-notes.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  echo "release notes check failed: $*" >&2
  exit 1
}

cat > "${TMP_DIR}/notes.md" <<'EOF'
# Changes
## 2026.10.6-rc.3
### Fixes
* Current release only.

## 2026.10.6-rc.2
### Fixes
* Previous release.
EOF

sh "${EXTRACT_NOTES}" \
  2026.10.6-rc.3 "${TMP_DIR}/notes.md" "${TMP_DIR}/current.md"

grep -Fxq '## 2026.10.6-rc.3' "${TMP_DIR}/current.md" \
  || fail "current release heading is missing"
grep -Fq 'Current release only.' "${TMP_DIR}/current.md" \
  || fail "current release content is missing"
if grep -Fq '2026.10.6-rc.2' "${TMP_DIR}/current.md"; then
  fail "previous release leaked into extracted GitHub notes"
fi

if sh "${EXTRACT_NOTES}" \
  2026.10.7 "${TMP_DIR}/notes.md" "${TMP_DIR}/missing.md" 2>/dev/null; then
  fail "missing release section was accepted"
fi
[ ! -e "${TMP_DIR}/missing.md" ] \
  || fail "failed extraction left an output file behind"

echo "release notes check: PASS"

