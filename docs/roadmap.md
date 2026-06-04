# Roadmap

## Milestone 0: Project Skeleton

- Define architecture and security model.
- Define open bridge server app layout.
- Add first boot bootstrap scripts.
- Add systemd unit placeholders.

## Milestone 1: Bootable Development Image

- Build a Debian-based x86_64 image.
- Install Docker Engine and Compose plugin.
- Install open bridge server app files under `/srv/obos`.
- Generate first boot secrets.
- Start open bridge server automatically.
- Verify health endpoint after boot.
- Run the security baseline audit and document deviations.

## Milestone 2: Raspberry Pi 4+ Image

- Build ARM64 image.
- Verify boot from SD and USB.
- Validate Docker and open bridge server startup.
- Validate host hardening on Raspberry Pi networking.
- Export boot-accessible TLS trust summary for headless onboarding.
- Maintain documented hardware and power requirements.

## Milestone 3: Appliance Web UI

- Show system status.
- Consume stable `obosctl status-summary` key-value output for read-only status.
- Show open bridge server status.
- Start, stop, restart, and update open bridge server.
- Show logs.
- Trigger backups and downloads.
- Consume stable `obosctl backup-list` key-value output for backup inventory.
- Configure hostname, timezone, and network basics.
- Surface hardening status and security baseline results.
- Surface TLS trust fingerprints and root CA export workflow.
- Provide explicit opt-in controls for LAN MQTT exposure.
- Consume stable `obosctl mqtt-summary` key-value output for MQTT exposure state.

## Milestone 4: Hardened Release

- First boot onboarding flow.
- Firewall defaults.
- SSH policy.
- TLS reverse proxy for open bridge server and obos UI.
- Per-appliance-instance local CA generation and trust onboarding.
- Certificate replacement/rotation workflow.
- Explicit MQTT external access opt-in workflow.
- Signed release artifacts and checksums.
- Update rollback notes.
- Security hardening checklist in CI.
