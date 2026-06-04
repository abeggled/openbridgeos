#!/usr/bin/env sh
set -eu

REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
CHECK_RELEASE_MANIFEST="${REPO_ROOT}/scripts/images/check-release-manifest.sh"

fail() {
  echo "release manifest creation failed: $1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

manifest_value() {
  key="$1"
  manifest_file="$2"

  awk -F= -v key="${key}" '
    $1 == key {
      print substr($0, length(key) + 2)
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "${manifest_file}" || fail "missing manifest key: ${key} in ${manifest_file}"
}

repo_revision() {
  if command -v git >/dev/null 2>&1 && git -C "${REPO_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse HEAD
  else
    echo unknown
  fi
}

[ "$#" -ge 2 ] || fail "usage: $0 <release-manifest> <image-manifest> [image-manifest...]"

OUTPUT_MANIFEST="$1"
shift

require_command awk
require_command date
require_command mkdir

[ -f "${CHECK_RELEASE_MANIFEST}" ] || fail "missing release manifest checker: ${CHECK_RELEASE_MANIFEST}"

created_at="$(date -u +%Y%m%dT%H%M%SZ)"
artifact_count="$#"
revision="$(repo_revision)"
tmp_manifest="${OUTPUT_MANIFEST}.tmp.$$"

mkdir -p "$(dirname -- "${OUTPUT_MANIFEST}")"

cat > "${tmp_manifest}" <<EOF
format=obos-release-bundle-v1
created_at=${created_at}
repo_revision=${revision}
signature_required=true
signature_type=minisign
signature_file=${OUTPUT_MANIFEST}.minisig
artifact_count=${artifact_count}
EOF

i=1
for image_manifest in "$@"; do
  [ -f "${image_manifest}" ] || fail "image manifest missing: ${image_manifest}"
  format="$(manifest_value format "${image_manifest}")"
  case "${format}" in
    obos-qcow2-build-v1|obos-rpi-image-build-v1) ;;
    *) fail "unsupported image manifest format: ${format}" ;;
  esac

  release_build="$(manifest_value release_build "${image_manifest}")"
  [ "${release_build}" = "1" ] || fail "release manifest requires release_build=1 in ${image_manifest}"

  prefix="artifact_${i}"
  cat >> "${tmp_manifest}" <<EOF
${prefix}_format=${format}
${prefix}_profile=$(manifest_value profile "${image_manifest}")
${prefix}_architecture=$(manifest_value architecture "${image_manifest}")
${prefix}_image=$(manifest_value image "${image_manifest}")
${prefix}_checksum_file=$(manifest_value checksum_file "${image_manifest}")
${prefix}_image_sha256=$(manifest_value image_sha256 "${image_manifest}")
${prefix}_manifest=${image_manifest}
EOF
  i=$((i + 1))
done

OBOS_MANIFEST_STRICT_FILES="${OBOS_MANIFEST_STRICT_FILES:-0}" sh "${CHECK_RELEASE_MANIFEST}" "${tmp_manifest}" >/dev/null
mv "${tmp_manifest}" "${OUTPUT_MANIFEST}"

printf 'release_manifest: %s\n' "${OUTPUT_MANIFEST}"
