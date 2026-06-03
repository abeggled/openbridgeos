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
- Run the security baseline audit and document deviations.

## Milestone 2: Raspberry Pi 4+ Image

- Build ARM64 image.
- Verify boot from SD and USB.
- Validate Docker and Open Bridge Server startup.
- Validate host hardening on Raspberry Pi networking.
- Explore boot-accessible TLS trust summary for headless onboarding.
- Document expected hardware and power requirements.

## Milestone 3: Appliance Web UI

- Show system status.
- Show Open Bridge Server status.
- Start, stop, restart, and update Open Bridge Server.
- Show logs.
- Trigger backups and downloads.
- Configure hostname, timezone, and network basics.
- Surface hardening status and security baseline results.
- Surface TLS trust fingerprints and root CA export workflow.
- Provide explicit opt-in controls for LAN MQTT exposure.

## Milestone 4: Hardened Release

- First boot onboarding flow.
- Firewall defaults.
- SSH policy.
- TLS reverse proxy for Open Bridge Server and obos UI.
- Per-device local CA generation and trust onboarding.
- Certificate replacement/rotation workflow.
- Explicit MQTT external access opt-in workflow.
- Signed release artifacts and checksums.
- Update rollback notes.
- Security hardening checklist in CI.
