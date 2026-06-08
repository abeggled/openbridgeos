#!/usr/bin/env sh
set -eu

TARGET="${1:-}"
GIT_REF="${2:-${OBOS_BUILD_REF:-}}"
REMOTE="${OBOS_BUILD_REMOTE:-origin}"
REPO_ROOT="${OBOS_REPO_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"

fail() {
  echo "pull and build failed: $1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
usage: scripts/images/pull-and-build.sh <amd64|arm64|all> [git-ref]

Examples:
  scripts/images/pull-and-build.sh amd64
  scripts/images/pull-and-build.sh arm64 codex/web-onboarding-password
  scripts/images/pull-and-build.sh all codex/web-onboarding-password

Environment:
  OBOS_BUILD_REF       Optional git ref when the second argument is omitted.
  OBOS_BUILD_REMOTE    Git remote name. Default: origin.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    require_command sudo
    sudo "$@"
  fi
}

current_branch() {
  git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD
}

update_repo() {
  require_command git

  if [ -n "${GIT_REF}" ]; then
    echo "pull and build: fetching ${REMOTE}/${GIT_REF}"
    git -C "${REPO_ROOT}" fetch "${REMOTE}" "${GIT_REF}"
    if git -C "${REPO_ROOT}" show-ref --verify --quiet "refs/heads/${GIT_REF}"; then
      git -C "${REPO_ROOT}" checkout "${GIT_REF}"
      git -C "${REPO_ROOT}" pull --ff-only "${REMOTE}" "${GIT_REF}"
    else
      git -C "${REPO_ROOT}" checkout -b "${GIT_REF}" FETCH_HEAD 2>/dev/null ||
        git -C "${REPO_ROOT}" checkout --detach FETCH_HEAD
    fi
  else
    branch="$(current_branch)"
    [ "${branch}" != HEAD ] || fail "detached HEAD requires an explicit git-ref"
    echo "pull and build: updating current branch ${branch}"
    git -C "${REPO_ROOT}" fetch "${REMOTE}"
    if git -C "${REPO_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      git -C "${REPO_ROOT}" pull --ff-only
    else
      git -C "${REPO_ROOT}" pull --ff-only "${REMOTE}" "${branch}"
    fi
  fi

  echo "pull and build: HEAD=$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
}

build_amd64() {
  echo "pull and build: building amd64 qcow2"
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/check-amd64-qcow2-build-host.sh)
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/build-amd64-qcow2.sh)
  (cd "${REPO_ROOT}" && sh scripts/images/check-qcow2-manifest.sh dist/images/obos-amd64-vm-latest.qcow2.manifest)
}

latest_rpi_root() {
  find "${REPO_ROOT}/build/images/rpi4-arm64" -maxdepth 1 -type d -name 'rootfs-*' -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    sed -n '1s/^[^ ]* //p'
}

build_arm64() {
  echo "pull and build: building Raspberry Pi arm64 image"
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/check-rpi4-arm64-build-host.sh)
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/build-rpi4-arm64-image.sh)

  latest_root="$(latest_rpi_root)"
  [ -n "${latest_root}" ] || fail "no Raspberry Pi rootfs build directory found"
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/check-rpi-boot-files.sh "${latest_root}")
  (cd "${REPO_ROOT}" && sudo_cmd sh scripts/images/check-rpi-kernel-config.sh "${latest_root}")
  (cd "${REPO_ROOT}" && sh scripts/images/check-rpi-image-manifest.sh dist/images/obos-rpi4-arm64-latest.img.xz.manifest)
  (cd "${REPO_ROOT}" && sha256sum -c dist/images/obos-rpi4-arm64-latest.img.xz.sha256)
}

case "$(printf '%s' "${TARGET}" | tr '[:upper:]' '[:lower:]')" in
  amd64)
    update_repo
    build_amd64
    ;;
  arm64)
    update_repo
    build_arm64
    ;;
  all)
    update_repo
    build_amd64
    build_arm64
    ;;
  -h|--help|help|"")
    usage
    exit 0
    ;;
  *)
    usage >&2
    fail "unsupported target: ${TARGET}"
    ;;
esac

echo "pull and build: PASS"
