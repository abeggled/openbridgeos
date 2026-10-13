#!/usr/bin/env sh
set -eu

[ "$#" -eq 3 ] || { echo "usage: create-update-bundle.sh <version> <output-dir> <release-notes-file>" >&2; exit 2; }

VERSION="$1"
OUTPUT_DIR="$2"
RELEASE_NOTES_FILE="$3"
REPO_ROOT="${OBOS_REPO_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}"
ARCHIVE="${OUTPUT_DIR}/obos-update.tar.gz"
MANIFEST="${OUTPUT_DIR}/obos-update.manifest"
NOTES="${OUTPUT_DIR}/obos-update-notes.txt"

printf '%s\n' "${VERSION}" | grep -Eq '^[0-9]+([.][0-9]+){1,3}([+~-][A-Za-z0-9.]+)?$' \
  || { echo "invalid OBOS update version: ${VERSION}" >&2; exit 1; }
git -C "${REPO_ROOT}" diff --quiet --ignore-submodules -- \
  || { echo "refusing to build an update bundle from a dirty worktree" >&2; exit 1; }
git -C "${REPO_ROOT}" diff --cached --quiet --ignore-submodules -- \
  || { echo "refusing to build an update bundle from a dirty index" >&2; exit 1; }
[ -s "${RELEASE_NOTES_FILE}" ] || { echo "release notes file is missing or empty" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}"
git -C "${REPO_ROOT}" archive --format=tar.gz --prefix=openbridgeos/ HEAD > "${ARCHIVE}"
cp "${RELEASE_NOTES_FILE}" "${NOTES}"
archive_sha256="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
notes_sha256="$(sha256sum "${NOTES}" | awk '{print $1}')"
revision="$(git -C "${REPO_ROOT}" rev-parse HEAD)"

cat > "${MANIFEST}" <<EOF
format=obos-update-release-v1
version=${VERSION}
revision=${revision}
archive=obos-update.tar.gz
archive_sha256=${archive_sha256}
root_dir=openbridgeos
notes=obos-update-notes.txt
notes_sha256=${notes_sha256}
EOF

echo "update_archive=${ARCHIVE}"
echo "update_manifest=${MANIFEST}"
echo "update_release_notes=${NOTES}"
echo "next=sign the manifest with: minisign -Sm ${MANIFEST}"
