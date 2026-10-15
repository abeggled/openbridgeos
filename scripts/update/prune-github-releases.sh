#!/usr/bin/env sh
set -eu

KEEP_PRERELEASES="${OBOS_RELEASE_KEEP_PRERELEASES:-1}"
KEEP_STABLES="${OBOS_RELEASE_KEEP_STABLES:-3}"
REPOSITORY="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
MODE="${1:-}"

for retention_count in "${KEEP_PRERELEASES}" "${KEEP_STABLES}"; do
  case "${retention_count}" in
    ""|*[!0-9]*)
      echo "release retention counts must be non-negative integers" >&2
      exit 2
      ;;
  esac
done
[ -n "${REPOSITORY}" ] || {
  echo "GH_REPO or GITHUB_REPOSITORY must identify the GitHub repository" >&2
  exit 2
}
case "${MODE}" in
  ""|--dry-run) confirmed=false ;;
  --confirm) confirmed=true ;;
  *) echo "usage: prune-github-releases.sh [--dry-run|--confirm]" >&2; exit 2 ;;
esac
command -v gh >/dev/null 2>&1 || { echo "gh is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT HUP INT TERM
releases_file="${work_dir}/releases.json"
plan_file="${work_dir}/plan.json"

gh api --paginate --slurp "repos/${REPOSITORY}/releases?per_page=100" |
  jq '[.[][] | select(.draft == false)]' > "${releases_file}"

jq \
  --argjson keep_prereleases "${KEEP_PRERELEASES}" \
  --argjson keep_stables "${KEEP_STABLES}" '
    sort_by(.published_at // .created_at) | reverse |
    . as $published |
    (([$published[] | select(.prerelease == true)][0:$keep_prereleases]) +
     ([$published[] | select(.prerelease == false)][0:$keep_stables])) as $keep |
    ($keep | map(.id)) as $keep_ids |
    {
      keep: $keep,
      delete: [$published[] | select(.id as $id | ($keep_ids | index($id) | not))]
    }
  ' "${releases_file}" > "${plan_file}"

echo "format=obos-github-release-retention-v1"
echo "repository=${REPOSITORY}"
echo "keep_prereleases=${KEEP_PRERELEASES}"
echo "keep_stables=${KEEP_STABLES}"
echo "mode=$([ "${confirmed}" = true ] && echo confirmed || echo dry-run)"
jq -r '.keep[] | "keep=" + .tag_name + "|prerelease=" + (.prerelease | tostring)' "${plan_file}"
jq -r '.delete[] | "delete=" + .tag_name + "|prerelease=" + (.prerelease | tostring)' "${plan_file}"

if [ "${confirmed}" = true ]; then
  jq -r '.delete[].tag_name' "${plan_file}" | while IFS= read -r tag_name; do
    [ -n "${tag_name}" ] || continue
    gh release delete "${tag_name}" --repo "${REPOSITORY}" --cleanup-tag --yes
    echo "deleted=${tag_name}"
  done
fi

echo "kept_count=$(jq '.keep | length' "${plan_file}")"
echo "delete_count=$(jq '.delete | length' "${plan_file}")"
echo "release_retention=ok"
