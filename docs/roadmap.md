# Roadmap

## Milestone 0: Project Skeleton

- Define architecture and security model.
- Define Open Bridge Server app layout.
- Add first boot bootstrap scripts.
- Add systemd unit placeholders.

## Milestone 1: Bootable Development Image

- Build a Debian-based x86_64 image.
- Install Docker Engine and Compose plugin.
- Install Open Bridge Server app files under `/srv/obos`.
- Generate first boot secrets.
- Start Open Bridge Server automatically.
- Verify health endpoint after boot.

## Milestone 2: Raspberry Pi 4+ Image

- Build ARM64 image.
- Verify boot from SD and USB.
- Validate Docker and Open Bridge Server startup.
- Document expected hardware and power requirements.

## Milestone 3: Appliance Web UI

- Show system status.
- Show Open Bridge Server status.
- Start, stop, restart, and update Open Bridge Server.
- Show logs.
- Trigger backups and downloads.
- Configure hostname, timezone, and network basics.

## Milestone 4: Hardened Release

- First boot onboarding flow.
- Firewall defaults.
- SSH policy.
- Signed release artifacts and checksums.
- Update rollback notes.
- Security hardening checklist in CI.
