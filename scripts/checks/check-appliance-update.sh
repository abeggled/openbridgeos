#!/usr/bin/env sh
set -eu

UPDATE_HOST="scripts/update/update-host.sh"
UPDATE_RELEASE="scripts/update/update-obos-release.sh"
INSTALL_BUNDLE="scripts/update/install-update-bundle.sh"
FIRST_BOOT="scripts/bootstrap/first-boot.sh"
PUBLIC_KEY="packaging/update/obos-release.minisign.pub"
RELEASE_WORKFLOW=".github/workflows/release-appliance.yml"

fail() {
  echo "appliance update fixture failed: $1" >&2
  exit 1
}

[ -f "${UPDATE_HOST}" ] || fail "host update helper missing"
[ -f "${UPDATE_RELEASE}" ] || fail "OBOS release update helper missing"
[ -f "${INSTALL_BUNDLE}" ] || fail "OBOS update bundle installer missing"
[ -f "${FIRST_BOOT}" ] || fail "first boot helper missing"
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
grep -q 'scripts/update/disable-install-media-sources.sh' "${INSTALL_BUNDLE}" \
  || fail "in-place updates do not install the CD-ROM source repair helper"
grep -q 'scripts/auth/manage-system-credentials.sh' "${INSTALL_BUNDLE}" \
  || fail "in-place updates do not install system credential management"
grep -q 'obos-system-credentials.service' "${INSTALL_BUNDLE}" \
  || fail "in-place updates do not install the credential initialization unit"
grep -q 'manage-system-credentials.sh.*ensure' "${INSTALL_BUNDLE}" \
  || fail "in-place updates do not initialize per-device recovery credentials"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
mock_bin="${tmp_dir}/bin"
modules_dir="${tmp_dir}/modules"
current_modules_dir="${tmp_dir}/modules-current"
apt_log="${tmp_dir}/apt.log"
pending_nginx_config="${tmp_dir}/openbridgeserver.conf.pending"
apt_etc_dir="${tmp_dir}/apt"
runtime_source_file="${tmp_dir}/run/obos-debian.sources"
mkdir -p "${mock_bin}" "${modules_dir}/6.12.0-obos" "${current_modules_dir}/6.12.0-obos"
mkdir -p "${apt_etc_dir}/sources.list.d"
printf '%s\n' 'VERSION_CODENAME=trixie' > "${tmp_dir}/os-release"

cat > "${apt_etc_dir}/sources.list" <<'EOF'
deb cdrom://[Debian GNU/Linux 13 _Trixie_ - Snapshot amd64 LIVE/INSTALL Binary 20261014-11:35] trixie main
deb https://deb.debian.org/debian trixie main
EOF
cat > "${apt_etc_dir}/sources.list.d/mixed.sources" <<'EOF'
Types: deb
  URIs: cdrom:[Debian GNU/Linux 13 _Trixie_]
Suites: trixie
Components: main

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main
EOF

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

cat > "${mock_bin}/nginx" <<'EOF'
#!/bin/sh
[ "${OBOS_TEST_NGINX_FAIL:-false}" != true ]
EOF

chmod +x "${mock_bin}/id" "${mock_bin}/apt-get" "${mock_bin}/uname" "${mock_bin}/nginx"

output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_DISABLE_INSTALL_MEDIA_SOURCES="${UPDATE_HOST%/update-host.sh}/disable-install-media-sources.sh" \
  OBOS_APT_ETC_DIR="${apt_etc_dir}" \
  OBOS_APT_RUNTIME_SOURCE_FILE="${runtime_source_file}" \
  OBOS_OS_RELEASE_FILE="${tmp_dir}/os-release" \
  sh "${UPDATE_HOST}"
)"

printf '%s\n' "${output}" | grep -q '^format=obos-host-update-v1$' \
  || fail "host update format missing"
printf '%s\n' "${output}" | grep -q '^os_packages_updated=true$' \
  || fail "host package success missing"
printf '%s\n' "${output}" | grep -q '^reboot_required=false$' \
  || fail "unchanged kernel unexpectedly requires reboot"
grep -Eq 'DPkg::Lock::Timeout=300 .* update$' "${apt_log}" \
  || fail "APT metadata refresh is missing lock timeout"
grep -q -- '--no-remove full-upgrade' "${apt_log}" \
  || fail "APT full upgrade is not protected against package removals"
grep -q -- '--no-remove install keyboard-configuration console-setup systemd-timesyncd' "${apt_log}" \
  || fail "host settings runtime packages are not installed during updates"
grep -Fq "Dir::Etc::sourcelist=${runtime_source_file}" "${apt_log}" \
  || fail "APT does not use the isolated runtime source list"
grep -Fq 'Dir::Etc::sourceparts=-' "${apt_log}" \
  || fail "APT still reads additional source files"
if grep -R -Eiq '^[[:space:]]*deb(-src)?[[:space:]].*cdrom:|^[[:space:]]*URIs[[:space:]]*:.*cdrom:' "${apt_etc_dir}"; then
  fail "installer CD-ROM APT source was not disabled before update"
fi
grep -Fq 'https://deb.debian.org/debian' "${apt_etc_dir}/sources.list" \
  || fail "network APT source was removed with the installer source"
grep -Fq 'https://security.debian.org/debian-security' "${apt_etc_dir}/sources.list.d/mixed.sources" \
  || fail "network deb822 stanza was removed with the installer source"

fallback_apt_etc_dir="${tmp_dir}/fallback-apt"
mkdir -p "${fallback_apt_etc_dir}/sources.list.d"
printf '%s\n' 'deb cdrom:[Debian GNU/Linux 13 _Trixie_]/ trixie main' > "${fallback_apt_etc_dir}/sources.list"
OBOS_APT_ETC_DIR="${fallback_apt_etc_dir}" \
OBOS_OS_RELEASE_FILE="${tmp_dir}/os-release" \
OBOS_APT_RUNTIME_SOURCE_FILE="${tmp_dir}/fallback-run/obos-debian.sources" \
sh scripts/update/disable-install-media-sources.sh >/dev/null
grep -Fq 'URIs: https://deb.debian.org/debian' "${fallback_apt_etc_dir}/sources.list.d/obos-debian.sources" \
  || fail "network Debian source was not created when the installer source was the only source"
grep -Fq 'Suites: trixie-security' "${fallback_apt_etc_dir}/sources.list.d/obos-debian.sources" \
  || fail "network Debian security source was not created"
grep -Fq 'URIs: https://deb.debian.org/debian' "${tmp_dir}/fallback-run/obos-debian.sources" \
  || fail "isolated runtime source was not created"

touch "${tmp_dir}/reboot-required"
output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_DISABLE_INSTALL_MEDIA_SOURCES="${UPDATE_HOST%/update-host.sh}/disable-install-media-sources.sh" \
  OBOS_APT_ETC_DIR="${apt_etc_dir}" \
  OBOS_APT_RUNTIME_SOURCE_FILE="${runtime_source_file}" \
  OBOS_OS_RELEASE_FILE="${tmp_dir}/os-release" \
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
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_DISABLE_INSTALL_MEDIA_SOURCES="${UPDATE_HOST%/update-host.sh}/disable-install-media-sources.sh" \
  OBOS_APT_ETC_DIR="${apt_etc_dir}" \
  OBOS_APT_RUNTIME_SOURCE_FILE="${runtime_source_file}" \
  OBOS_OS_RELEASE_FILE="${tmp_dir}/os-release" \
  sh "${UPDATE_HOST}"
)"
printf '%s\n' "${output}" | grep -q '^reboot_reason=kernel-changed$' \
  || fail "newly installed kernel does not require reboot"

printf 'staged nginx configuration\n' > "${pending_nginx_config}"
output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_APT_GET=apt-get \
  OBOS_UNAME=uname \
  OBOS_MODULES_DIR="${current_modules_dir}" \
  OBOS_REBOOT_REQUIRED_FILE="${tmp_dir}/reboot-required" \
  OBOS_UPDATE_LOG_FILE="${tmp_dir}/update.log" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_DISABLE_INSTALL_MEDIA_SOURCES="${UPDATE_HOST%/update-host.sh}/disable-install-media-sources.sh" \
  OBOS_APT_ETC_DIR="${apt_etc_dir}" \
  OBOS_APT_RUNTIME_SOURCE_FILE="${runtime_source_file}" \
  OBOS_OS_RELEASE_FILE="${tmp_dir}/os-release" \
  sh "${UPDATE_HOST}"
)"
printf '%s\n' "${output}" | grep -q '^reboot_required=true$' \
  || fail "staged nginx configuration does not require reboot"
printf '%s\n' "${output}" | grep -q '^reboot_reason=obos-release-pending$' \
  || fail "staged nginx configuration reboot reason is missing"

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

channel_file="${tmp_dir}/update/release-channel"
legacy_base_url_file="${tmp_dir}/update/release-base-url"
mkdir -p "$(dirname -- "${channel_file}")"
printf '%s\n' 'https://github.com/abeggled/openbridgeos/releases/download/legacy-test' > "${legacy_base_url_file}"
channel_output="$(
  PATH="${mock_bin}:${PATH}" \
  OBOS_RELEASE_CHANNEL_FILE="${channel_file}" \
  OBOS_RELEASE_BASE_URL_FILE="${legacy_base_url_file}" \
  sh scripts/obosctl set-release-channel prerelease --confirm set-release-channel
)"
printf '%s\n' "${channel_output}" | grep -q '^release_channel=prerelease$' \
  || fail "release channel mutation did not report prerelease"
[ "$(cat "${channel_file}")" = prerelease ] \
  || fail "release channel mutation did not persist prerelease"
[ ! -e "${legacy_base_url_file}" ] \
  || fail "release channel mutation did not remove the legacy URL override"
if PATH="${mock_bin}:${PATH}" \
  OBOS_RELEASE_CHANNEL_FILE="${channel_file}" \
  OBOS_RELEASE_BASE_URL_FILE="${legacy_base_url_file}" \
  sh scripts/obosctl set-release-channel 'prerelease;id' --confirm set-release-channel >/dev/null 2>&1; then
  fail "release channel mutation accepted an invalid channel"
fi
channel_summary="$(
  OBOS_RELEASE_CHANNEL_FILE="${channel_file}" \
  OBOS_RELEASE_BASE_URL_FILE="${legacy_base_url_file}" \
  sh scripts/obosctl release-channel-summary
)"
printf '%s\n' "${channel_summary}" | grep -q '^release_channel=prerelease$' \
  || fail "release channel summary did not report the configured channel"

prerelease_curl="${mock_bin}/prerelease-curl"
cat > "${prerelease_curl}" <<'EOF'
#!/bin/sh
output=
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then
    shift
    output="${1:-}"
  fi
  shift
done
[ -n "${output}" ] || exit 2
printf '%s\n' '[]' > "${output}"
EOF
chmod +x "${prerelease_curl}"
printf '%s\n' 'fixture public key' > "${tmp_dir}/fixture-public-key"
release_prerelease_output="$(
  OBOS_CURL="${prerelease_curl}" \
  OBOS_MINISIGN=true \
  OBOS_RELEASE_CHANNEL_FILE="${channel_file}" \
  OBOS_RELEASE_BASE_URL_FILE="${legacy_base_url_file}" \
  OBOS_RELEASE_PUBLIC_KEY_FILE="${tmp_dir}/fixture-public-key" \
  sh "${UPDATE_RELEASE}" check
)"
printf '%s\n' "${release_prerelease_output}" | grep -q '^release_channel=prerelease$' \
  || fail "release updater did not resolve the prerelease channel"
printf '%s\n' "${release_prerelease_output}" | grep -q '^release_status=no-prerelease$' \
  || fail "release updater did not report an empty prerelease channel safely"

release_fixture="${tmp_dir}/release-fixture"
mkdir -p "${release_fixture}"
cat > "${release_fixture}/obos-update-notes.txt" <<'EOF'
# Changes
## 2026.10.3
### New features ✨
* newest change with `code`
## 2026.10.2
### Fixes 🐞
* intermediate change
## 2026.10.1
### Security fixes 🔒
* first update after the installed version
## 2026.10.0
### New features ✨
* already installed and must not be shown
EOF
notes_fixture_sha="$(sha256sum "${release_fixture}/obos-update-notes.txt" | awk '{print $1}')"
cat > "${release_fixture}/obos-update.manifest" <<EOF
format=obos-update-release-v1
version=2026.10.3
revision=0123456789abcdef0123456789abcdef01234567
archive=obos-update.tar.gz
archive_sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
root_dir=openbridgeos
notes=obos-update-notes.txt
notes_sha256=${notes_fixture_sha}
EOF
: > "${release_fixture}/obos-update.manifest.minisig"
printf '%s\n' '2026.10.0' > "${tmp_dir}/installed-version"
release_fixture_curl="${mock_bin}/release-fixture-curl"
cat > "${release_fixture_curl}" <<'EOF'
#!/bin/sh
output=
write_status=false
url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) shift; output="${1:-}" ;;
    -w) shift; write_status=true ;;
    http*) url="$1" ;;
  esac
  shift
done
[ -n "${output}" ] && [ -n "${url}" ] || exit 2
cp "${OBOS_TEST_RELEASE_FIXTURE:?}/${url##*/}" "${output}"
if [ "${write_status}" = true ]; then
  printf '200'
fi
EOF
chmod +x "${release_fixture_curl}"
filtered_release_output="$(
  OBOS_CURL="${release_fixture_curl}" \
  OBOS_MINISIGN=true \
  OBOS_TEST_RELEASE_FIXTURE="${release_fixture}" \
  OBOS_RELEASE_BASE_URL=https://github.com/abeggled/openbridgeos/releases/download/2026.10.3 \
  OBOS_RELEASE_PUBLIC_KEY_FILE="${tmp_dir}/fixture-public-key" \
  OBOS_VERSION_FILE="${tmp_dir}/installed-version" \
  sh "${UPDATE_RELEASE}" check
)"
printf '%s\n' "${filtered_release_output}" | grep -q '^release_notes_from_version=2026.10.0$' \
  || fail "release preview omitted its installed-version boundary"
printf '%s\n' "${filtered_release_output}" | grep -q '^release_notes_to_version=2026.10.3$' \
  || fail "release preview omitted its available-version boundary"
printf '%s\n' "${filtered_release_output}" | grep -q 'release_note_001=## 2026.10.3' \
  || fail "release preview did not start at the available release"
printf '%s\n' "${filtered_release_output}" | grep -q 'first update after the installed version' \
  || fail "release preview omitted an intermediate release"
if printf '%s\n' "${filtered_release_output}" | grep -q 'already installed and must not be shown'; then
  fail "release preview included notes for the installed release"
fi

cat > "${release_fixture}/obos-update-notes.txt" <<'EOF'
# Changes
## 2026.10.4
### Fixes 🐞
* stable promotion
## 2026.10.4-rc.1
### Fixes 🐞
* installed release candidate
EOF
notes_fixture_sha="$(sha256sum "${release_fixture}/obos-update-notes.txt" | awk '{print $1}')"
cat > "${release_fixture}/obos-update.manifest" <<EOF
format=obos-update-release-v1
version=2026.10.4
revision=0123456789abcdef0123456789abcdef01234567
archive=obos-update.tar.gz
archive_sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
root_dir=openbridgeos
notes=obos-update-notes.txt
notes_sha256=${notes_fixture_sha}
EOF
printf '%s\n' '2026.10.4-rc.1' > "${tmp_dir}/installed-version"
stable_promotion_output="$(
  OBOS_CURL="${release_fixture_curl}" \
  OBOS_MINISIGN=true \
  OBOS_TEST_RELEASE_FIXTURE="${release_fixture}" \
  OBOS_RELEASE_BASE_URL=https://github.com/abeggled/openbridgeos/releases/download/2026.10.4 \
  OBOS_RELEASE_PUBLIC_KEY_FILE="${tmp_dir}/fixture-public-key" \
  OBOS_VERSION_FILE="${tmp_dir}/installed-version" \
  sh "${UPDATE_RELEASE}" check
)"
printf '%s\n' "${stable_promotion_output}" | grep -q '^update_available=true$' \
  || fail "stable release was not newer than its release candidate"
printf '%s\n' "${stable_promotion_output}" | grep -q 'stable promotion' \
  || fail "stable promotion notes were not shown after a release candidate"
if printf '%s\n' "${stable_promotion_output}" | grep -q 'installed release candidate'; then
  fail "release preview repeated notes for the installed release candidate"
fi

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
grep -q 'PENDING_NGINX_CONFIG="/etc/obos/update/openbridgeserver.conf.pending"' "${INSTALL_BUNDLE}" \
  || fail "update bundle installer does not stage reboot-dependent nginx configuration"
# shellcheck disable=SC2016
grep -Fq 'include ${PENDING_NGINX_CONFIG};' "${INSTALL_BUNDLE}" \
  || fail "update bundle installer does not validate the staged nginx configuration"
pending_install_line="$(grep -n 'packaging/nginx/openbridgeserver.conf.*PENDING_NGINX_CONFIG' "${INSTALL_BUNDLE}" | cut -d: -f1)"
coordinated_install_line="$(grep -n 'install-openbridgeserver-app.sh.*APP_SOURCE' "${INSTALL_BUNDLE}" | cut -d: -f1)"
[ "${pending_install_line}" -gt "${coordinated_install_line}" ] \
  || fail "update bundle stages nginx before coordinated files finish installing"
compat_install_line="$(grep -n 'compat_tmp=.*AGENT_HTTP_COMPAT_ENV' "${INSTALL_BUNDLE}" | cut -d: -f1)"
agent_unit_install_line="$(grep -n '^for unit in' "${INSTALL_BUNDLE}" | cut -d: -f1)"
[ "${compat_install_line}" -lt "${agent_unit_install_line}" ] \
  || fail "update bundle installs agent units before preserving listener compatibility"
grep -q 'finalize_pending_nginx_config' scripts/bootstrap/first-boot.sh \
  || fail "first boot does not activate staged nginx configuration"
grep -q 'EnvironmentFile=-/etc/obos/update/agent-http-compat.env' packaging/systemd/obos-agent-http.service \
  || fail "agent service cannot enter the nginx rollback compatibility mode"
grep -q '/etc/nginx/sites-available' packaging/systemd/obos-first-boot.service \
  || fail "first boot sandbox cannot activate staged nginx configuration"
if grep -q 'systemctl reload nginx.service' "${INSTALL_BUNDLE}"; then
  fail "update bundle installer activates reboot-dependent nginx changes before reboot"
fi

first_boot_etc="${tmp_dir}/first-boot-etc"
first_boot_state="${tmp_dir}/first-boot-state"
active_nginx_config="${tmp_dir}/nginx/active.conf"
pending_nginx_config="${first_boot_etc}/update/openbridgeserver.conf.pending"
previous_nginx_config="${first_boot_etc}/update/openbridgeserver.conf.previous"
agent_http_compat_env="${first_boot_etc}/update/agent-http-compat.env"
mkdir -p "${first_boot_etc}/update" "${first_boot_state}" "$(dirname -- "${active_nginx_config}")"
printf 'configured web auth\n' > "${first_boot_etc}/web.htpasswd"
printf 'first boot complete\n' > "${first_boot_state}/first-boot.done"
printf 'old nginx config\n' > "${active_nginx_config}"
printf 'new nginx config\n' > "${pending_nginx_config}"
printf 'stale compatibility mode\n' > "${agent_http_compat_env}"
PATH="${mock_bin}:${PATH}" \
OBOS_ETC_DIR="${first_boot_etc}" \
OBOS_STATE_DIR="${first_boot_state}" \
OBOS_APP_DIR="${tmp_dir}/app" \
OBOS_ACTIVE_NGINX_CONFIG="${active_nginx_config}" \
OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
OBOS_PREVIOUS_NGINX_CONFIG="${previous_nginx_config}" \
OBOS_AGENT_HTTP_COMPAT_ENV="${agent_http_compat_env}" \
sh "${FIRST_BOOT}"
grep -q '^new nginx config$' "${active_nginx_config}" \
  || fail "first boot did not activate the staged nginx configuration"
[ ! -e "${pending_nginx_config}" ] \
  || fail "first boot retained an activated nginx configuration"
[ ! -e "${agent_http_compat_env}" ] \
  || fail "first boot retained agent compatibility mode after successful activation"

printf 'proxy_pass http://127.0.0.1:8091;\n' > "${active_nginx_config}"
printf 'invalid nginx config\n' > "${pending_nginx_config}"
if PATH="${mock_bin}:${PATH}" \
  OBOS_TEST_NGINX_FAIL=true \
  OBOS_ETC_DIR="${first_boot_etc}" \
  OBOS_STATE_DIR="${first_boot_state}" \
  OBOS_APP_DIR="${tmp_dir}/app" \
  OBOS_ACTIVE_NGINX_CONFIG="${active_nginx_config}" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_PREVIOUS_NGINX_CONFIG="${previous_nginx_config}" \
  OBOS_AGENT_HTTP_COMPAT_ENV="${agent_http_compat_env}" \
  sh "${FIRST_BOOT}" >/dev/null 2>&1; then
  fail "first boot accepted an invalid staged nginx configuration"
fi
grep -q '^proxy_pass http://127.0.0.1:8091;$' "${active_nginx_config}" \
  || fail "first boot did not restore nginx configuration after validation failure"
[ -s "${pending_nginx_config}" ] \
  || fail "first boot discarded a failed staged nginx configuration"
grep -q '^OBOS_AGENT_HTTP_SOCKET=$' "${agent_http_compat_env}" \
  || fail "first boot did not enable TCP agent compatibility after nginx rollback"

rm -f "${previous_nginx_config}"
printf 'proxy_pass http://unix:/run/obos-agent-http/agent.sock:;\n' > "${active_nginx_config}"
printf 'invalid replacement nginx config\n' > "${pending_nginx_config}"
if PATH="${mock_bin}:${PATH}" \
  OBOS_TEST_NGINX_FAIL=true \
  OBOS_ETC_DIR="${first_boot_etc}" \
  OBOS_STATE_DIR="${first_boot_state}" \
  OBOS_APP_DIR="${tmp_dir}/app" \
  OBOS_ACTIVE_NGINX_CONFIG="${active_nginx_config}" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_PREVIOUS_NGINX_CONFIG="${previous_nginx_config}" \
  OBOS_AGENT_HTTP_COMPAT_ENV="${agent_http_compat_env}" \
  sh "${FIRST_BOOT}" >/dev/null 2>&1; then
  fail "first boot accepted a conflicting replacement nginx configuration"
fi
grep -q '^proxy_pass http://unix:/run/obos-agent-http/agent.sock:;$' "${active_nginx_config}" \
  || fail "first boot did not preserve the prior socket nginx configuration"
[ ! -e "${agent_http_compat_env}" ] \
  || fail "first boot enabled TCP compatibility for a socket-based nginx rollback"

printf 'proxy_pass http://127.0.0.1:8091;\n' > "${previous_nginx_config}"
printf 'interrupted invalid nginx config\n' > "${active_nginx_config}"
printf 'invalid replacement nginx config\n' > "${pending_nginx_config}"
if PATH="${mock_bin}:${PATH}" \
  OBOS_TEST_NGINX_FAIL=true \
  OBOS_ETC_DIR="${first_boot_etc}" \
  OBOS_STATE_DIR="${first_boot_state}" \
  OBOS_APP_DIR="${tmp_dir}/app" \
  OBOS_ACTIVE_NGINX_CONFIG="${active_nginx_config}" \
  OBOS_PENDING_NGINX_CONFIG="${pending_nginx_config}" \
  OBOS_PREVIOUS_NGINX_CONFIG="${previous_nginx_config}" \
  OBOS_AGENT_HTTP_COMPAT_ENV="${agent_http_compat_env}" \
  sh "${FIRST_BOOT}" >/dev/null 2>&1; then
  fail "first boot accepted an interrupted invalid nginx activation"
fi
grep -q '^proxy_pass http://127.0.0.1:8091;$' "${active_nginx_config}" \
  || fail "first boot overwrote the known-good nginx recovery copy"

echo "appliance update fixture: PASS"
