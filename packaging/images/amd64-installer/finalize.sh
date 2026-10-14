#!/bin/sh
set -eu

DEBCONF_MODULE="${OBOS_INSTALLER_DEBCONF_MODULE:-/usr/share/debconf/confmodule}"
INSTALLER_TEMPLATES="${OBOS_INSTALLER_TEMPLATES:-/usr/share/obos-installer/installer.templates}"
TARGET_ROOT="${OBOS_INSTALLER_TARGET_ROOT:-/target}"
IN_TARGET="${OBOS_INSTALLER_IN_TARGET:-in-target}"
IP_COMMAND="${OBOS_INSTALLER_IP_COMMAND:-ip}"

# shellcheck disable=SC1090
. "${DEBCONF_MODULE}"
debconf-loadtemplate obos-installer "${INSTALLER_TEMPLATES}"

"${IN_TARGET}" /usr/lib/obos/manage-system-credentials.sh ensure >/dev/null
"${IN_TARGET}" /usr/lib/obos/disable-install-media-sources.sh >/dev/null

credentials_file="${TARGET_ROOT}/etc/obos/system-credentials"
obos_password="$(sed -n 's/^obos_password=//p' "${credentials_file}" | head -n 1)"
printf '%s\n' "${obos_password}" | grep -Eq '^[A-Za-z0-9_-]{20,}$' || exit 1

ip_address="$("${IP_COMMAND}" -4 -o addr show scope global 2>/dev/null \
  | awk '$3 == "inet" { split($4, address, "/"); print address[1]; exit }')"
if [ -n "${ip_address}" ]; then
  web_url="https://${ip_address}/obos/"
else
  ip_address="not assigned - check the DHCP server after reboot"
  web_url="https://obos.local/obos/"
fi

db_subst obos-installer/recovery-password OBOS_PASSWORD "${obos_password}"
db_subst obos-installer/recovery-password IP_ADDRESS "${ip_address}"
db_subst obos-installer/recovery-password WEB_URL "${web_url}"
db_fset obos-installer/recovery-password seen false
db_input critical obos-installer/recovery-password || true
db_go
db_unregister obos-installer/recovery-password || true
obos_password=

