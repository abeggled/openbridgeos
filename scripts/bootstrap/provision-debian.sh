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
OBOS_VERSION="${OBOS_VERSION:-0.0.0}"
OBOS_IMAGE_BUILD="${OBOS_IMAGE_BUILD:-0}"
RUNTIME_PACKAGES_FILE="${REPO_ROOT}/packaging/images/obos-runtime-packages.list.chroot"

case "${OBOS_IMAGE_BUILD}" in
  0|1) ;;
  *)
    echo "OBOS_IMAGE_BUILD must be 0 or 1" >&2
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive

apt-get update
[ -s "${RUNTIME_PACKAGES_FILE}" ] || {
  echo "OBOS runtime package list is missing: ${RUNTIME_PACKAGES_FILE}" >&2
  exit 1
}
xargs apt-get install -y --no-install-recommends < "${RUNTIME_PACKAGES_FILE}"

if ! getent passwd obos-agent >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin --user-group obos-agent
fi
if ! getent passwd obos >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash obos
fi
if getent group sudo >/dev/null 2>&1; then
  usermod --append --groups sudo obos
fi

install -d -m 0755 "${OBOS_SHARE_DIR}/apps/openbridgeserver"
install -d -m 0755 "${OBOS_LIB_DIR}"
install -d -m 0755 /etc/apt/apt.conf.d /etc/docker /etc/logrotate.d /etc/obos/apps /etc/obos/update /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/sudoers.d /etc/systemd/network
install -d -m 0750 -o root -g www-data /etc/obos
install -d -m 0750 -g www-data /srv/obos
install -d -m 0750 /srv/obos/apps /srv/obos/backups
# The HTTP bridge runs as obos-agent and owns private directories below
# /srv/obos/state. Keep the parent root-owned, but make it traversable by the
# agent group so onboarding markers and session state are actually reachable.
install -d -m 0750 -o root -g obos-agent /srv/obos/state
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
install -m 0644 "${REPO_ROOT}/apps/obos-web/diagnostics.html" "${OBOS_WEB_DIR}/diagnostics.html"
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
install -m 0755 "${REPO_ROOT}/scripts/auth/manage-system-credentials.sh" "${OBOS_LIB_DIR}/manage-system-credentials.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/apply-host-hardening.sh" "${OBOS_LIB_DIR}/apply-host-hardening.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/enable-ssh.sh" "${OBOS_LIB_DIR}/enable-ssh.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/set-mqtt-lan-access.sh" "${OBOS_LIB_DIR}/set-mqtt-lan-access.sh"
install -m 0755 "${REPO_ROOT}/scripts/update/update-host.sh" "${OBOS_LIB_DIR}/update-host.sh"
install -m 0755 "${REPO_ROOT}/scripts/update/update-obos-release.sh" "${OBOS_LIB_DIR}/update-obos-release.sh"
install -m 0755 "${REPO_ROOT}/scripts/update/install-update-bundle.sh" "${OBOS_LIB_DIR}/install-update-bundle.sh"
install -m 0755 "${REPO_ROOT}/scripts/update/disable-install-media-sources.sh" "${OBOS_LIB_DIR}/disable-install-media-sources.sh"
if [ -n "${OBOS_RELEASE_MINISIGN_PUBLIC_KEY:-}" ]; then
  printf '%s\n' "${OBOS_RELEASE_MINISIGN_PUBLIC_KEY}" > /etc/obos/update/minisign.pub
  chmod 0644 /etc/obos/update/minisign.pub
elif [ -s "${REPO_ROOT}/packaging/update/obos-release.minisign.pub" ]; then
  install -m 0644 "${REPO_ROOT}/packaging/update/obos-release.minisign.pub" /etc/obos/update/minisign.pub
fi
printf '%s\n' "${OBOS_VERSION}" > /etc/obos/version
chmod 0644 /etc/obos/version
install -m 0755 "${REPO_ROOT}/scripts/audit/security-baseline.sh" "${OBOS_LIB_DIR}/security-baseline.sh"
install -m 0755 "${REPO_ROOT}/scripts/audit/mvp-runtime-readiness.sh" "${OBOS_LIB_DIR}/mvp-runtime-readiness.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/generate-tls-material.sh" "${OBOS_LIB_DIR}/generate-tls-material.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/check-tls-status.sh" "${OBOS_LIB_DIR}/check-tls-status.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/plan-leaf-renewal.sh" "${OBOS_LIB_DIR}/plan-leaf-renewal.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/renew-leaf-certificate.sh" "${OBOS_LIB_DIR}/renew-leaf-certificate.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/auto-renew-leaf-certificate.sh" "${OBOS_LIB_DIR}/auto-renew-leaf-certificate.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/print-trust-info.sh" "${OBOS_LIB_DIR}/print-trust-info.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/export-trust-bundle.sh" "${OBOS_LIB_DIR}/export-trust-bundle.sh"
install -m 0755 "${REPO_ROOT}/scripts/tls/export-boot-trust-summary.sh" "${OBOS_LIB_DIR}/export-boot-trust-summary.sh"
install -m 0755 "${REPO_ROOT}/scripts/obosctl" /usr/bin/obosctl
install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent.sh" /usr/bin/obos-agent
install -m 0755 "${REPO_ROOT}/scripts/agent/obos-agent-http.py" "${OBOS_LIB_DIR}/obos-agent-http.py"
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-first-boot.service" /etc/systemd/system/obos-first-boot.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-system-credentials.service" /etc/systemd/system/obos-system-credentials.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-agent-http.service" /etc/systemd/system/obos-agent-http.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-openbridgeserver.service" /etc/systemd/system/obos-openbridgeserver.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-tls-leaf-renewal.service" /etc/systemd/system/obos-tls-leaf-renewal.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-tls-leaf-renewal.timer" /etc/systemd/system/obos-tls-leaf-renewal.timer

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/obos-openbridgeserver.conf /etc/nginx/sites-enabled/obos-openbridgeserver.conf
ln -snf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

"${OBOS_LIB_DIR}/install-openbridgeserver-app.sh" "${OBOS_APP_SOURCE}"
"${OBOS_LIB_DIR}/apply-host-hardening.sh"

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl enable docker.service
systemctl enable nginx.service
systemctl enable obos-agent-http.service
systemctl enable obos-system-credentials.service
systemctl enable obos-first-boot.service
systemctl enable obos-openbridgeserver.service
systemctl enable obos-tls-leaf-renewal.timer
systemctl enable apt-daily.timer
systemctl enable apt-daily-upgrade.timer

if [ "${OBOS_IMAGE_BUILD}" = "0" ]; then
  systemctl daemon-reload
  systemctl restart docker.service
fi

# Do not run first boot during image creation. Secrets and TLS material must be
# generated on the target appliance instance, not in the build environment.
