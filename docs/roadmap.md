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

- Add static appliance console shell.
- Show system status.
- Consume stable `obosctl status-summary` key-value output for read-only status.
- Show open bridge server status.
- Start, stop, restart, and update open bridge server.
- Consume stable `obosctl update-summary` key-value output for last update state.
- Show logs.
- Trigger backups and downloads.
- Export encrypted portable backups for download and migration.
- Import encrypted portable backups into private staging.
- Consume stable `obosctl backup-list` key-value output for backup inventory.
- Configure hostname, timezone, and network basics.
- Surface hardening status and security baseline results.
- Consume stable `obosctl security-summary` key-value output for baseline status.
- Surface TLS trust fingerprints and root CA export workflow.
- Consume stable `obosctl tls-summary` key-value output for TLS trust state.
- Provide explicit opt-in controls for LAN MQTT exposure.
- Consume stable `obosctl mqtt-summary` key-value output for MQTT exposure state.

Current implementation status:

- Static obos web shell is installed below `/srv/obos/web` and served below
  `/obos/`.
- `obos-agent-http.service` exposes selected read-only `obos-agent` actions and
  the confirmed backup mutation below `/obos/api/` on the same HTTPS origin.
- The web shell consumes read-only status, update, backup, restore staging,
  host basics, logs metadata, MQTT, TLS, security baseline, and agent audit
  summary fields.
- Start, stop, restart, update, and backup creation are exposed as the first
  confirmed HTTP mutations through `obos-agent`.
- Backup download is intentionally limited to the future encrypted portable
  backup format.
- Non-destructive encrypted portable backup export/import planning exists in
  `obosctl` and `obos-agent`.
- Encrypted portable backup creation/download/upload/decryption, log viewing,
  hostname, timezone, network basics, and MQTT/TLS mutation controls are still
  future UI work.

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
