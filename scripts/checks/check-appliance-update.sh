#!/usr/bin/env sh
set -eu

UPDATE_HOST="scripts/update/update-host.sh"
UPDATE_RELEASE="scripts/update/update-obos-release.sh"
INSTALL_BUNDLE="scripts/update/install-update-bundle.sh"
PUBLIC_KEY="packaging/update/obos-release.minisign.pub"
RELEASE_WORKFLOW=".github/workflows/release-appliance.yml"

fail() {
  echo "appliance update fixture failed: $1" >&2
  exit 1
}

[ -f "${UPDATE_HOST}" ] || fail "host update helper missing"
[ -f "${UPDATE_RELEASE}" ] || fail "OBOS release update helper missing"
[ -f "${INSTALL_BUNDLE}" ] || fail "OBOS update bundle installer missing"
[ -s "${PUBLIC_KEY}" ] || fail "pinned OBOS release public key missing"
[ -s "${RELEASE_WORKFLOW}" ] || fail "GitHub appliance release workflow missing"
[ "$(wc -l < "${PUBLIC_KEY}")" -eq 2 ] || fail "pinned release public key has an unexpected format"
grep -Eq '^untrusted comment: minisign public key [A-F0-9]{16}$' "${PUBLIC_KEY}" \
  || fail "pinned release public key identifier is invalid"
grep -Eq '^RW[A-Za-z0-9+/]{54}$' "${PUBLIC_KEY}" \
  || fail "pinned release public key payload is invalid"
if grep -qi 'secret key' "${PUBLIC_KEY}"; then
  fail "release public-key file contains secret-key material"
fi
grep -q '^  workflow_dispatch:' "${RELEASE_WORKFLOW}" \
  || fail "release workflow is not manually gated"
grep -q '^    environment: release$' "${RELEASE_WORKFLOW}" \
  || fail "release workflow does not use the release environment"
grep -q 'contents: write' "${RELEASE_WORKFLOW}" \
  || fail "release job cannot publish GitHub assets"
grep -q 'secrets.OBOS_RELEASE_MINISIGN_SECRET_KEY' "${RELEASE_WORKFLOW}" \
  || fail "release workflow does not use the environment signing key"
grep -q '^            -W' "${RELEASE_WORKFLOW}" \
  || fail "release workflow does not use the dedicated passwordless CI key"
if grep -q 'OBOS_RELEASE_MINISIGN_PASSWORD' "${RELEASE_WORKFLOW}"; then
  fail "release workflow still requires a signing-key password"
fi
grep -q 'Refusing to replace existing release' "${RELEASE_WORKFLOW}" \
  || fail "release workflow can replace an existing release"
grep -q 'packaging/update/obos-release.minisign.pub' "${RELEASE_WORKFLOW}" \
  || fail "release workflow does not publish the release public key"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
mock_bin="${tmp_dir}/bin"
modules_dir="${tmp_dir}/modules"
apt_log="${tmp_dir}/apt.log"
mkdir -p "${mock_bin}" "${modules_dir}/6.12.0-obos"

cat > "${mock_bin}/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = "-u" ] && printf '0\n'
EOF

cat > "${mock_bin}/apt-get" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "${apt_log}"
EOF

cat > "${mock_bin}/uname" <<'EOF'
#!/bin/sh
[ "${1:-}" = "-r" ] && printf '6.12.0-obos\n'
EOF

chmod +x "${mock_bin}/id" "${mock_bin}/apt-get" "${mock_bin}/uname"

output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  sh "${UPDATE_HOST}"
)"

printf '%s\n' "${output}" | grep -q '^format=obos-host-update-v1$' \
  || fail "host update format missing"
printf '%s\n' "${output}" | grep -q '^os_packages_updated=true$' \
  || fail "host package success missing"
printf '%s\n' "${output}" | grep -q '^reboot_required=false$' \
  || fail "unchanged kernel unexpectedly requires reboot"
grep -q 'DPkg::Lock::Timeout=300 update' "${apt_log}" \
  || fail "APT metadata refresh is missing lock timeout"
grep -q -- '--no-remove full-upgrade' "${apt_log}" \
  || fail "APT full upgrade is not protected against package removals"

touch "${tmp_dir}/reboot-required"
output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  sh "${UPDATE_HOST}"
)"
printf '%s\n' "${output}" | grep -q '^reboot_required=true$' \
  || fail "package reboot marker is ignored"
printf '%s\n' "${output}" | grep -q '^reboot_reason=package-marker$' \
  || fail "package reboot reason is missing"

rm -f "${tmp_dir}/reboot-required"
mkdir -p "${modules_dir}/6.13.0-obos"
output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  sh "${UPDATE_HOST}"
)"
printf '%s\n' "${output}" | grep -q '^reboot_reason=kernel-changed$' \
  || fail "newly installed kernel does not require reboot"

release_output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_RELEASE_PUBLIC_KEY_FILE="${tmp_dir}/missing-public-key" \
  sh "${UPDATE_RELEASE}"
)"
printf '%s\n' "${release_output}" | grep -q '^release_status=not-configured$' \
  || fail "release updater does not fail closed without a pinned public key"
printf '%s\n' "${release_output}" | grep -q '^release_updated=false$' \
  || fail "release updater claims an unverified update"

release_check_output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_RELEASE_PUBLIC_KEY_FILE="${tmp_dir}/missing-public-key" \
  OBOS_VERSION_FILE="${tmp_dir}/missing-version" \
  sh "${UPDATE_RELEASE}" check
)"
printf '%s\n' "${release_check_output}" | grep -q '^installed_version=0.0.0$' \
  || fail "release preview does not report the installed fallback version"
printf '%s\n' "${release_check_output}" | grep -q '^release_notes_present=false$' \
  || fail "release preview claims unsigned release notes"

# shellcheck disable=SC2016
grep -q '\-Vm "${manifest}"' "${UPDATE_RELEASE}" \
  || fail "release updater does not verify the signed manifest"
grep -q 'archive checksum mismatch' "${UPDATE_RELEASE}" \
  || fail "release updater does not verify the archive checksum"
grep -q 'release notes checksum mismatch' "${UPDATE_RELEASE}" \
  || fail "release updater does not verify the release notes checksum"
grep -q 'release_note_%03d' "${UPDATE_RELEASE}" \
  || fail "release updater does not expose bounded signed release notes"
grep -q 'abeggled/openbridgeos/releases/download/' "${UPDATE_RELEASE}" \
  || fail "release updater does not constrain the configured prerelease channel"
grep -q 'release archive contains unsafe paths' "${UPDATE_RELEASE}" \
  || fail "release updater does not reject unsafe archive paths"
grep -q '/etc/obos/version' "${INSTALL_BUNDLE}" \
  || fail "update bundle installer does not record the installed OBOS version"

echo "appliance update fixture: PASS"
