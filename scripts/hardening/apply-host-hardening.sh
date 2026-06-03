#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "apply-host-hardening.sh must run as root" >&2
  exit 1
fi

NFT_FILE="${OBOS_NFT_FILE:-/etc/nftables.conf}"
SYSCTL_FILE="${OBOS_SYSCTL_FILE:-/etc/sysctl.d/99-obos-hardening.conf}"
DISABLE_SSH="${OBOS_DISABLE_SSH:-1}"

if [ -f "${NFT_FILE}" ]; then
  nft -c -f "${NFT_FILE}"
  systemctl enable nftables.service
  systemctl restart nftables.service
else
  echo "missing nftables rules: ${NFT_FILE}" >&2
  exit 1
fi

if [ -f "${SYSCTL_FILE}" ]; then
  sysctl --system >/dev/null
else
  echo "missing sysctl hardening file: ${SYSCTL_FILE}" >&2
  exit 1
fi

if [ "${DISABLE_SSH}" = "1" ] && systemctl list-unit-files ssh.service >/dev/null 2>&1; then
  systemctl disable --now ssh.service >/dev/null 2>&1 || true
fi
