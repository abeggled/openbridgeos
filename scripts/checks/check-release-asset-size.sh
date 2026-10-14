#!/usr/bin/env sh
set -eu

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
small="${tmp_dir}/small"
large="${tmp_dir}/large"
printf '1234' > "${small}"
printf '123456' > "${large}"

OBOS_RELEASE_ASSET_MAX_BYTES=4 sh scripts/images/check-release-asset-size.sh "${small}" >/dev/null
if OBOS_RELEASE_ASSET_MAX_BYTES=4 sh scripts/images/check-release-asset-size.sh "${large}" >/dev/null 2>&1; then
  echo "release asset size fixture failed: oversized asset was accepted" >&2
  exit 1
fi
echo "release asset size fixture: PASS"
