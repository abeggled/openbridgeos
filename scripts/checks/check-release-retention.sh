#!/usr/bin/env sh
set -eu

fail() { echo "release retention fixture failed: $1" >&2; exit 1; }

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
mkdir -p "${tmp_dir}/bin"

cat > "${tmp_dir}/bin/gh" <<'EOF'
#!/bin/sh
if [ "${1:-}" = api ]; then
  cat <<'JSON'
[[
  {"id":8,"tag_name":"2.0.0-rc.2","draft":false,"prerelease":true,"published_at":"2026-02-08T00:00:00Z"},
  {"id":7,"tag_name":"2.0.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-02-07T00:00:00Z"},
  {"id":6,"tag_name":"1.3.0","draft":false,"prerelease":false,"published_at":"2026-02-06T00:00:00Z"},
  {"id":5,"tag_name":"1.2.0","draft":false,"prerelease":false,"published_at":"2026-02-05T00:00:00Z"},
  {"id":4,"tag_name":"1.1.0","draft":false,"prerelease":false,"published_at":"2026-02-04T00:00:00Z"},
  {"id":3,"tag_name":"1.0.0","draft":false,"prerelease":false,"published_at":"2026-02-03T00:00:00Z"},
  {"id":2,"tag_name":"0.9.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-02-02T00:00:00Z"},
  {"id":1,"tag_name":"draft","draft":true,"prerelease":false,"published_at":null}
]]
JSON
  exit 0
fi
if [ "${1:-}" = release ] && [ "${2:-}" = delete ]; then
  printf '%s\n' "${3}" >> "${OBOS_TEST_DELETE_LOG}"
  exit 0
fi
exit 2
EOF
chmod 0755 "${tmp_dir}/bin/gh"
: > "${tmp_dir}/deleted.log"

output="$(PATH="${tmp_dir}/bin:${PATH}" GH_REPO=example/obos \
  OBOS_TEST_DELETE_LOG="${tmp_dir}/deleted.log" \
  sh scripts/update/prune-github-releases.sh --dry-run)"
printf '%s\n' "${output}" | grep -Fq 'keep=2.0.0-rc.2|prerelease=true' || fail "newest prerelease was not retained"
for tag in 1.3.0 1.2.0 1.1.0; do
  printf '%s\n' "${output}" | grep -Fq "keep=${tag}|prerelease=false" || fail "stable ${tag} was not retained"
done
for tag in 2.0.0-rc.1 1.0.0 0.9.0-rc.1; do
  printf '%s\n' "${output}" | grep -Fq "delete=${tag}|" || fail "old release ${tag} was not selected"
done
[ ! -s "${tmp_dir}/deleted.log" ] || fail "dry run deleted releases"

PATH="${tmp_dir}/bin:${PATH}" GH_REPO=example/obos \
  OBOS_TEST_DELETE_LOG="${tmp_dir}/deleted.log" \
  sh scripts/update/prune-github-releases.sh --confirm >/dev/null
[ "$(wc -l < "${tmp_dir}/deleted.log")" -eq 3 ] || fail "confirmed run deleted the wrong count"
grep -Fxq '2.0.0-rc.1' "${tmp_dir}/deleted.log" || fail "old prerelease was not deleted"
grep -Fxq '1.0.0' "${tmp_dir}/deleted.log" || fail "fourth stable release was not deleted"
grep -Fxq '0.9.0-rc.1' "${tmp_dir}/deleted.log" || fail "older prerelease was not deleted"

: > "${tmp_dir}/deleted.log"
PATH="${tmp_dir}/bin:${PATH}" GITHUB_REPOSITORY=example/actions-obos \
  OBOS_TEST_DELETE_LOG="${tmp_dir}/deleted.log" \
  sh scripts/update/prune-github-releases.sh --dry-run >/dev/null
[ ! -s "${tmp_dir}/deleted.log" ] || fail "GitHub Actions repository fallback was not a dry run"

echo "release retention fixture: PASS"
