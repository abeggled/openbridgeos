#!/usr/bin/env sh
set -eu

[ "$#" -eq 3 ] || {
  echo "usage: extract-release-notes.sh <version> <release-notes-file> <output-file>" >&2
  exit 2
}

version="$1"
release_notes_file="$2"
output_file="$3"

printf '%s\n' "${version}" | grep -Eq '^[0-9]+([.][0-9]+){1,3}([+~-][A-Za-z0-9.]+)?$' \
  || { echo "invalid OBOS release version: ${version}" >&2; exit 1; }
[ -s "${release_notes_file}" ] \
  || { echo "release notes file is missing or empty: ${release_notes_file}" >&2; exit 1; }

output_dir="$(dirname -- "${output_file}")"
mkdir -p "${output_dir}"

awk -v version="${version}" '
  $0 == "## " version {
    found = 1
    printing = 1
  }
  printing && $0 ~ /^## / && $0 != "## " version {
    exit
  }
  printing {
    print
  }
  END {
    if (!found) {
      exit 1
    }
  }
' "${release_notes_file}" > "${output_file}" || {
  rm -f -- "${output_file}"
  echo "release notes do not contain a section for ${version}" >&2
  exit 1
}

[ -s "${output_file}" ] \
  || { echo "extracted release notes are empty for ${version}" >&2; exit 1; }

