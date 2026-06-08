#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "provision-debian.sh must run as root" >&2
  exit 1
fi

REPO_ROOT="${1:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
OBOS_SHARE_DIR="/usr/share/obos"
OBOS_LIB_DIR="/usr/lib/obos"
OBOS_APP_SOURCE="${OBOS_SHARE_DIR}/apps/openbridgeserver"
OBOS_WEB_DIR="/srv/obos/web"
OBOS_ONBOARDING_DIR="/srv/obos/onboarding"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  docker-cli \
  docker-compose \
  docker.io \
  gnupg \
  logrotate \
  nftables \
  nginx-light \
  openssl \
  python3-minimal \
  sudo \
  unattended-upgrades

if ! getent passwd obos-agent >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin --user-group obos-agent
fi

install -d -m 0755 "${OBOS_SHARE_DIR}/apps/openbridgeserver"
install -d -m 0755 "${OBOS_LIB_DIR}"
install -d -m 0755 /etc/apt/apt.conf.d /etc/docker /etc/logrotate.d /etc/obos /etc/obos/apps /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/sudoers.d /etc/systemd/network
install -d -m 0750 -g www-data /srv/obos
install -d -m 0750 /srv/obos/apps /srv/obos/backups /srv/obos/state
install -d -m 0755 "${OBOS_WEB_DIR}"
install -d -m 0755 "${OBOS_ONBOARDING_DIR}"
install -d -m 0750 -o obos-agent -g obos-agent /srv/obos/state/agent
install -d -m 0700 -o obos-agent -g obos-agent /srv/obos/state/onboarding
install -d -m 0700 -o obos-agent -g obos-agent /srv/obos/state/portable-imports
install -d -m 0700 -o obos-agent -g obos-agent /srv/obos/state/sessions

install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/compose.yaml" "${OBOS_APP_SOURCE}/compose.yaml"
install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/mosquitto.conf" "${OBOS_APP_SOURCE}/mosquitto.conf"
install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/obos-app.yaml" "${OBOS_APP_SOURCE}/obos-app.yaml"
install -m 0644 "${REPO_ROOT}/apps/obos-web/index.html" "${OBOS_WEB_DIR}/index.html"
install -m 0644 "${REPO_ROOT}/apps/obos-web/styles.css" "${OBOS_WEB_DIR}/styles.css"
install -m 0644 "${REPO_ROOT}/apps/obos-web/app.js" "${OBOS_WEB_DIR}/app.js"
install -m 0644 "${REPO_ROOT}/apps/obos-onboarding/index.html" "${OBOS_ONBOARDING_DIR}/index.html"
install -m 0644 "${REPO_ROOT}/apps/obos-onboarding/styles.css" "${OBOS_ONBOARDING_DIR}/styles.css"
install -m 0644 "${REPO_ROOT}/apps/obos-onboarding/onboarding.js" "${OBOS_ONBOARDING_DIR}/onboarding.js"
install -m 0644 "${REPO_ROOT}/packaging/apt/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
install -m 0644 "${REPO_ROOT}/packaging/apt/50unattended-upgrades" /etc/apt/apt.conf.d/50unattended-upgrades
install -m 0644 "${REPO_ROOT}/packaging/docker/daemon.json" /etc/docker/daemon.json
install -m 0644 "${REPO_ROOT}/packaging/logrotate/obos-agent" /etc/logrotate.d/obos-agent
install -m 0644 "${REPO_ROOT}/packaging/nftables/obos.nft" /etc/nftables.conf
install -m 0644 "${REPO_ROOT}/packaging/network/20-obos-dhcp.network" /etc/systemd/network/20-obos-dhcp.network
install -m 0644 "${REPO_ROOT}/packaging/nginx/openbridgeserver.conf" /etc/nginx/sites-available/obos-openbridgeserver.conf
install -m 0440 "${REPO_ROOT}/packaging/sudoers/obos-agent" /etc/sudoers.d/obos-agent
install -m 0644 "${REPO_ROOT}/packaging/sysctl/99-obos-hardening.conf" /etc/sysctl.d/99-obos-hardening.conf
install -m 0755 "${REPO_ROOT}/scripts/bootstrap/first-boot.sh" "${OBOS_LIB_DIR}/first-boot.sh"
install -m 0755 "${REPO_ROOT}/scripts/bootstrap/install-openbridgeserver-app.sh" "${OBOS_LIB_DIR}/install-openbridgeserver-app.sh"
install -m 0755 "${REPO_ROOT}/scripts/auth/generate-web-auth.sh" "${OBOS_LIB_DIR}/generate-web-auth.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/apply-host-hardening.sh" "${OBOS_LIB_DIR}/apply-host-hardening.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/enable-ssh.sh" "${OBOS_LIB_DIR}/enable-ssh.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/set-mqtt-lan-access.sh" "${OBOS_LIB_DIR}/set-mqtt-lan-access.sh"
install -m 0755 "${REPO_ROOT}/scripts/audit/security-baseline.sh" "${OBOS_LIB_DIR}/security-baseline.sh"
install -m 0755 "${REPO_ROOT}/scripts/audit/mvp-runtime-readiness.sh" "${OBOS_LIB_DIR}/mvp-runtime-readiness.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/generate-tls-material.sh" "${OBOS_LIB_DIR}/generate-tls-material.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/check-tls-status.sh" "${OBOS_LIB_DIR}/check-tls-status.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/plan-leaf-renewal.sh" "${OBOS_LIB_DIR}/plan-leaf-renewal.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/renew-leaf-certificate.sh" "${OBOS_LIB_DIR}/renew-leaf-certificate.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/print-trust-info.sh" "${OBOS_LIB_DIR}/print-trust-info.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/export-trust-bundle.sh" "${OBOS_LIB_DIR}/export-trust-bundle.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/export-boot-trust-summary.sh" "${OBOS_LIB_DIR}/export-boot-trust-summary.sh"
install -m 0755 "${REPO_ROOT}/scripts/obosctl" /usr/bin/obosctl
install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent.sh" /usr/bin/obos-agent
install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent-http.py" "${OBOS_LIB_DIR}/obos-agent-http.py"
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-first-boot.service" /etc/systemd/system/obos-first-boot.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-agent-http.service" /etc/systemd/system/obos-agent-http.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-openbridgeserver.service" /etc/systemd/system/obos-openbridgeserver.service

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/obos-openbridgeserver.conf /etc/nginx/sites-enabled/obos-openbridgeserver.conf

"${OBOS_LIB_DIR}/install-openbridgeserver-app.sh" "${OBOS_APP_SOURCE}"
"${OBOS_LIB_DIR}/apply-host-hardening.sh"

systemctl daemon-reload
systemctl enable systemd-networkd.service
systemctl restart docker.service
systemctl enable docker.service
systemctl enable nginx.service
systemctl enable obos-agent-http.service
systemctl enable obos-first-boot.service
systemctl enable obos-openbridgeserver.service
systemctl enable apt-daily.timer
systemctl enable apt-daily-upgrade.timer

# Do not run first boot during image creation. Secrets and TLS material must be
# generated on the target appliance instance, not in the build environment.
