#!/usr/bin/env sh
set -eu

[ "$(id -u)" -eq 0 ] || { echo "OBOS update bundle installer must run as root" >&2; exit 1; }
[ "$#" -eq 2 ] || { echo "usage: install-update-bundle.sh <release-root> <version>" >&2; exit 2; }

RELEASE_ROOT="$1"
VERSION="$2"
OBOS_LIB_DIR="/usr/lib/obos"
OBOS_SHARE_DIR="/usr/share/obos"
OBOS_WEB_DIR="/srv/obos/web"
OBOS_ONBOARDING_DIR="/srv/obos/onboarding"
APP_SOURCE="${OBOS_SHARE_DIR}/apps/openbridgeserver"
PENDING_NGINX_CONFIG="/etc/obos/update/openbridgeserver.conf.pending"
ACTIVE_NGINX_CONFIG="/etc/nginx/sites-available/obos-openbridgeserver.conf"
AGENT_HTTP_COMPAT_ENV="/etc/obos/update/agent-http-compat.env"

for required in \
  apps/openbridgeserver/compose.yaml \
  apps/obos-web/index.html \
  apps/obos-web/app.js \
  scripts/obosctl \
  scripts/agent/obos-agent.sh \
  scripts/agent/obos-agent-http.py \
  packaging/nginx/openbridgeserver.conf; do
  [ -f "${RELEASE_ROOT}/${required}" ] || {
    echo "OBOS update bundle missing: ${required}" >&2
    exit 1
  }
done

install -d -m 0755 "${APP_SOURCE}" "${OBOS_LIB_DIR}" "${OBOS_WEB_DIR}" "${OBOS_ONBOARDING_DIR}"
install -d -m 0755 /etc/apt/apt.conf.d /etc/docker /etc/logrotate.d /etc/obos/update /etc/nginx/sites-available /etc/sudoers.d /etc/systemd/network /etc/systemd/system

if [ -f "${ACTIVE_NGINX_CONFIG}" ] && grep -Fq 'proxy_pass http://127.0.0.1:8091' "${ACTIVE_NGINX_CONFIG}"; then
  compat_tmp="$(mktemp "${AGENT_HTTP_COMPAT_ENV}.XXXXXX")"
  cat > "${compat_tmp}" <<'EOF'
OBOS_AGENT_HTTP_SOCKET=
OBOS_AGENT_HTTP_BIND=127.0.0.1
OBOS_AGENT_HTTP_PORT=8091
EOF
  chmod 0600 "${compat_tmp}"
  mv "${compat_tmp}" "${AGENT_HTTP_COMPAT_ENV}"
else
  rm -f "${AGENT_HTTP_COMPAT_ENV}"
fi

install -m 0644 "${RELEASE_ROOT}/apps/openbridgeserver/compose.yaml" "${APP_SOURCE}/compose.yaml"
install -m 0644 "${RELEASE_ROOT}/apps/openbridgeserver/mosquitto.conf" "${APP_SOURCE}/mosquitto.conf"
install -m 0644 "${RELEASE_ROOT}/apps/openbridgeserver/obos-app.yaml" "${APP_SOURCE}/obos-app.yaml"
install -m 0644 "${RELEASE_ROOT}/apps/obos-web/index.html" "${OBOS_WEB_DIR}/index.html"
install -m 0644 "${RELEASE_ROOT}/apps/obos-web/diagnostics.html" "${OBOS_WEB_DIR}/diagnostics.html"
install -m 0644 "${RELEASE_ROOT}/apps/obos-web/styles.css" "${OBOS_WEB_DIR}/styles.css"
install -m 0644 "${RELEASE_ROOT}/apps/obos-web/app.js" "${OBOS_WEB_DIR}/app.js"
install -m 0644 "${RELEASE_ROOT}/apps/obos-onboarding/index.html" "${OBOS_ONBOARDING_DIR}/index.html"
install -m 0644 "${RELEASE_ROOT}/apps/obos-onboarding/styles.css" "${OBOS_ONBOARDING_DIR}/styles.css"
install -m 0644 "${RELEASE_ROOT}/apps/obos-onboarding/onboarding.js" "${OBOS_ONBOARDING_DIR}/onboarding.js"

install -m 0644 "${RELEASE_ROOT}/packaging/apt/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
install -m 0644 "${RELEASE_ROOT}/packaging/apt/50unattended-upgrades" /etc/apt/apt.conf.d/50unattended-upgrades
install -m 0644 "${RELEASE_ROOT}/packaging/docker/daemon.json" /etc/docker/daemon.json
install -m 0644 "${RELEASE_ROOT}/packaging/logrotate/obos-agent" /etc/logrotate.d/obos-agent
install -m 0644 "${RELEASE_ROOT}/packaging/nftables/obos.nft" /etc/nftables.conf
install -m 0644 "${RELEASE_ROOT}/packaging/network/20-obos-dhcp.network" /etc/systemd/network/20-obos-dhcp.network
install -m 0440 "${RELEASE_ROOT}/packaging/sudoers/obos-agent" /etc/sudoers.d/obos-agent
install -m 0644 "${RELEASE_ROOT}/packaging/sysctl/99-obos-hardening.conf" /etc/sysctl.d/99-obos-hardening.conf

install -m 0755 "${RELEASE_ROOT}/scripts/obosctl" /usr/bin/obosctl
install -m 0755 "${RELEASE_ROOT}/scripts/agent/obos-agent.sh" /usr/bin/obos-agent
install -m 0755 "${RELEASE_ROOT}/scripts/agent/obos-agent-http.py" "${OBOS_LIB_DIR}/obos-agent-http.py"
for script in \
  scripts/bootstrap/first-boot.sh \
  scripts/bootstrap/install-openbridgeserver-app.sh \
  scripts/auth/generate-web-auth.sh \
  scripts/hardening/apply-host-hardening.sh \
  scripts/hardening/enable-ssh.sh \
  scripts/hardening/set-mqtt-lan-access.sh \
  scripts/audit/security-baseline.sh \
  scripts/audit/mvp-runtime-readiness.sh \
  scripts/tls/generate-tls-material.sh \
  scripts/tls/check-tls-status.sh \
  scripts/tls/plan-leaf-renewal.sh \
  scripts/tls/renew-leaf-certificate.sh \
  scripts/tls/auto-renew-leaf-certificate.sh \
  scripts/tls/print-trust-info.sh \
  scripts/tls/export-trust-bundle.sh \
  scripts/tls/export-boot-trust-summary.sh \
  scripts/update/update-host.sh \
  scripts/update/update-obos-release.sh \
  scripts/update/install-update-bundle.sh; do
  install -m 0755 "${RELEASE_ROOT}/${script}" "${OBOS_LIB_DIR}/$(basename -- "${script}")"
done

for unit in \
  obos-first-boot.service \
  obos-agent-http.service \
  obos-openbridgeserver.service \
  obos-tls-leaf-renewal.service \
  obos-tls-leaf-renewal.timer; do
  install -m 0644 "${RELEASE_ROOT}/packaging/systemd/${unit}" "/etc/systemd/system/${unit}"
done

"${OBOS_LIB_DIR}/install-openbridgeserver-app.sh" "${APP_SOURCE}"
install -m 0644 "${RELEASE_ROOT}/packaging/nginx/openbridgeserver.conf" "${PENDING_NGINX_CONFIG}"
systemctl daemon-reload
validation_config="$(mktemp /run/obos-nginx-validation.XXXXXX)"
trap 'rm -f "${validation_config}"' EXIT HUP INT TERM
cat > "${validation_config}" <<EOF
pid /run/obos-nginx-validation.pid;
events {}
http {
  include /etc/nginx/mime.types;
  include ${PENDING_NGINX_CONFIG};
}
EOF
nginx -t -c "${validation_config}"
rm -f "${validation_config}"
trap - EXIT HUP INT TERM
printf '%s\n' "${VERSION}" > /etc/obos/version
chmod 0644 /etc/obos/version

echo "format=obos-update-bundle-install-v1"
echo "version=${VERSION}"
echo "installed=true"
