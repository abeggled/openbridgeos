#!/usr/bin/env sh
set -eu

APT_ETC_DIR="${OBOS_APT_ETC_DIR:-/etc/apt}"
OS_RELEASE_FILE="${OBOS_OS_RELEASE_FILE:-/etc/os-release}"
APT_RUNTIME_SOURCE_FILE="${OBOS_APT_RUNTIME_SOURCE_FILE:-/run/obos-update/obos-debian.sources}"

codename="$(sed -n 's/^VERSION_CODENAME=//p' "${OS_RELEASE_FILE}" 2>/dev/null | tr -d '"' | head -n 1)"
printf '%s\n' "${codename}" | grep -Eq '^[a-z][a-z0-9-]*$' \
  || { echo "cannot configure Debian network sources: invalid VERSION_CODENAME" >&2; exit 1; }

write_debian_sources() {
  destination="$1"
  destination_dir="$(dirname -- "${destination}")"
  install -d -m 0755 "${destination_dir}"
  temporary_file="$(mktemp "${destination_dir}/.obos-debian.sources.XXXXXX")"
  trap 'rm -f "${temporary_file}"' EXIT HUP INT TERM
  cat > "${temporary_file}" <<EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: ${codename} ${codename}-updates
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: ${codename}-security
Components: main non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
  chmod 0644 "${temporary_file}"
  mv -f "${temporary_file}" "${destination}"
  trap - EXIT HUP INT TERM
}

# Host updates use this isolated source file explicitly. This makes stale or
# unusually formatted installer-media entries unable to participate in APT,
# even if a persistent source file could not be recognized and rewritten.
write_debian_sources "${APT_RUNTIME_SOURCE_FILE}"

rewrite_list_file() {
  source_file="$1"
  temporary_file="${source_file}.obos.$$"
  sed '/^[[:space:]]*deb\(-src\)\{0,1\}[[:space:]].*cdrom:/s/^/# disabled by OBOS after installation: /' \
    "${source_file}" > "${temporary_file}"
  chmod --reference="${source_file}" "${temporary_file}" 2>/dev/null || chmod 0644 "${temporary_file}"
  chown --reference="${source_file}" "${temporary_file}" 2>/dev/null || true
  mv -f "${temporary_file}" "${source_file}"
}

rewrite_deb822_file() {
  source_file="$1"
  temporary_file="${source_file}.obos.$$"
  awk 'BEGIN { RS=""; ORS="\n\n" }
    tolower($0) !~ /(^|\n)[[:space:]]*uris[[:space:]]*:[^\n]*cdrom:/ { print }
  ' "${source_file}" > "${temporary_file}"
  chmod --reference="${source_file}" "${temporary_file}" 2>/dev/null || chmod 0644 "${temporary_file}"
  chown --reference="${source_file}" "${temporary_file}" 2>/dev/null || true
  mv -f "${temporary_file}" "${source_file}"
}

if [ -f "${APT_ETC_DIR}/sources.list" ] && grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*cdrom:' "${APT_ETC_DIR}/sources.list"; then
  rewrite_list_file "${APT_ETC_DIR}/sources.list"
fi

if [ -d "${APT_ETC_DIR}/sources.list.d" ]; then
  for source_file in "${APT_ETC_DIR}"/sources.list.d/*.list; do
    [ -f "${source_file}" ] || continue
    if grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*cdrom:' "${source_file}"; then
      rewrite_list_file "${source_file}"
    fi
  done
  for source_file in "${APT_ETC_DIR}"/sources.list.d/*.sources; do
    [ -f "${source_file}" ] || continue
    if grep -Eiq '^[[:space:]]*URIs[[:space:]]*:.*cdrom:' "${source_file}"; then
      rewrite_deb822_file "${source_file}"
    fi
  done
fi

active_network_source=false
if [ -f "${APT_ETC_DIR}/sources.list" ] \
  && grep -Eq '^[[:space:]]*deb(-src)?[[:space:]].*https?://' "${APT_ETC_DIR}/sources.list"; then
  active_network_source=true
fi
if [ -d "${APT_ETC_DIR}/sources.list.d" ] \
  && grep -R -Eiq '^[[:space:]]*deb(-src)?[[:space:]].*https?://|^[[:space:]]*URIs[[:space:]]*:.*https?://' \
    "${APT_ETC_DIR}/sources.list.d" 2>/dev/null; then
  active_network_source=true
fi

if [ "${active_network_source}" = false ]; then
  fallback_sources="${APT_ETC_DIR}/sources.list.d/obos-debian.sources"
  write_debian_sources "${fallback_sources}"
  echo "network_sources_created=true"
else
  echo "network_sources_created=false"
fi

echo "install_media_sources_disabled=true"
echo "apt_runtime_source_file=${APT_RUNTIME_SOURCE_FILE}"

