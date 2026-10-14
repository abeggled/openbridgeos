#!/bin/sh
set -eu

# shellcheck disable=SC1091
. /usr/share/debconf/confmodule
debconf-loadtemplate obos-installer /usr/share/obos-installer/installer.templates

in-target /usr/lib/obos/manage-system-credentials.sh ensure >/dev/null
in-target /usr/lib/obos/disable-install-media-sources.sh >/dev/null

credentials_file=/target/etc/obos/system-credentials
obos_password="$(sed -n 's/^obos_password=//p' "${credentials_file}" | head -n 1)"
printf '%s\n' "${obos_password}" | grep -Eq '^[A-Za-z0-9_-]{20,}$' || exit 1

db_subst obos-installer/recovery-password OBOS_PASSWORD "${obos_password}"
db_fset obos-installer/recovery-password seen false
db_input critical obos-installer/recovery-password || true
db_go
db_unregister obos-installer/recovery-password || true
obos_password=

