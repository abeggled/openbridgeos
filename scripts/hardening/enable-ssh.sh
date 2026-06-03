#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "enable-ssh.sh must run as root" >&2
  exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
  echo "openssh-server is not installed" >&2
  echo "Install it explicitly before enabling SSH on this appliance." >&2
  exit 1
fi

systemctl enable --now ssh.service
cat <<'EOF'
SSH has been enabled.

Security checklist:
- Prefer key-based login.
- Disable password login after onboarding.
- Do not expose SSH to the internet.
- Revisit nftables rules before expecting remote SSH access.
EOF
