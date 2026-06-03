#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "provision-debian.sh must run as root" >&2
  exit 1
fi

REPO_ROOT="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}"
OBOS_SHARE_DIR="/usr/share/obos"
OBOS_LIB_DIR="/usr/lib/obos"
OBOS_APP_SOURCE="${OBOS_SHARE_DIR}/apps/openbridgeserver"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  docker-compose \
  docker.io \
  nftables \
  openssl

install -d -m 0755 "${OBOS_SHARE_DIR}/apps/openbridgeserver"
install -d -m 0755 "${OBOS_LIB_DIR}"
install -d -m 0755 /etc/obos /etc/obos/apps
install -d -m 0750 /srv/obos /srv/obos/apps /srv/obos/backups /srv/obos/state

install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/compose.yaml" "${OBOS_APP_SOURCE}/compose.yaml"
install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/mosquitto.conf" "${OBOS_APP_SOURCE}/mosquitto.conf"
install -m 0644 "${REPO_ROOT}/apps/openbridgeserver/obos-app.yaml" "${OBOS_APP_SOURCE}/obos-app.yaml"
install -m 0644 "${REPO_ROOT}/packaging/nftables/obos.nft" /etc/nftables.conf
install -m 0644 "${REPO_ROOT}/packaging/sysctl/99-obos-hardening.conf" /etc/sysctl.d/99-obos-hardening.conf
install -m 0755 "${REPO_ROOT}/scripts/bootstrap/first-boot.sh" "${OBOS_LIB_DIR}/first-boot.sh"
install -m 0755 "${REPO_ROOT}/scripts/bootstrap/install-openbridgeserver-app.sh" "${OBOS_LIB_DIR}/install-openbridgeserver-app.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/apply-host-hardening.sh" "${OBOS_LIB_DIR}/apply-host-hardening.sh"
install -m 0755 "${REPO_ROOT}/scripts/hardening/enable-ssh.sh" "${OBOS_LIB_DIR}/enable-ssh.sh"
install -m 0755 "${REPO_ROOT}/scripts/obosctl" /usr/bin/obosctl
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-first-boot.service" /etc/systemd/system/obos-first-boot.service
install -m 0644 "${REPO_ROOT}/packaging/systemd/obos-openbridgeserver.service" /etc/systemd/system/obos-openbridgeserver.service

"${OBOS_LIB_DIR}/install-openbridgeserver-app.sh" "${OBOS_APP_SOURCE}"
"${OBOS_LIB_DIR}/apply-host-hardening.sh"

systemctl daemon-reload
systemctl enable docker.service
systemctl enable obos-first-boot.service
systemctl enable obos-openbridgeserver.service

# Do not run first boot during image creation. Secrets must be generated on the
# target device, not in the build environment.
