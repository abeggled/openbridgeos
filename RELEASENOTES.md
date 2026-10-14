# Changes
## 2026.10.6-rc.5
### Fixes 🐞
* Run host package updates against an isolated, signed HTTPS Debian source list so stale installer `cdrom:` entries can no longer block an in-place update.
* Recognize Deb822 installer-media fields with indentation or variant capitalization when cleaning the persistent APT configuration.
* Start each appliance-update log with the current attempt instead of repeating failures from earlier attempts in the Action card.
### Security fixes 🔒
* Disable all supplemental APT source parts during the privileged host upgrade, preventing unrecognized install-media or third-party source files from influencing that transaction.
### Operational notes 🔔
* Appliances on RC.3 or a partially installed RC.4 can install RC.5 directly from the prerelease channel by selecting **Update Appliance** again; no console repair is required.

## 2026.10.6-rc.4
### New features ✨
* Start the amd64 appliance installer automatically after a five-second BIOS or UEFI countdown while retaining explicit advanced and rescue options.
* Automatically partition and install GRUB when exactly one eligible internal disk is present, after one destructive confirmation that shows the disk device, model, and size.
* Generate different per-device passwords for the Linux `root` and `obos` recovery users on the target system and show the `obos` password before the installer reboots.
* Reveal or rotate both Linux recovery passwords under System Diagnostics only after the current web-admin password is entered again.
### Security fixes 🔒
* Stop automatic installation without selecting a real disk when zero or multiple eligible target disks are detected.
* Store recovery credentials root-only, exclude them from normal status, logs, releases, and backups, and audit every reveal or rotation without logging the secrets.
### Fixes 🐞
* Disable stale installer `cdrom:` APT sources before appliance updates and create signed Debian network sources when the install medium was the only configured source.
### Operational notes 🔔
* Existing RC.3 appliances can install this update through the prerelease channel; the repaired host-update helper is installed before the Debian package refresh runs.

## 2026.10.6-rc.3
### Breaking changes 🚨
* Remove the one-time setup-token requirement from initial web onboarding so setup no longer requires console or boot-media access.
### Fixes 🐞
* Let non-technical administrators create the first `admin` password entirely in the browser.
### Operational notes 🔔
* Keep an uninitialized appliance on a trusted local setup network; the browser-only first-client-wins setup window remains limited to five minutes per boot and closes permanently when the password is set.

## 2026.10.6-rc.2
### Fixes 🐞
* Keep all OBOS runtime packages in amd64 ISO installations instead of allowing the Debian live installer to remove packages installed by the provisioning hook.
* Validate during every ISO build that Python, nginx, and the complete shared runtime package set remain in the installed-system package manifest.

## 2026.10.6-rc.1
### New features ✨
* Publish a bootable amd64 installer ISO, an amd64 qcow2 VM disk, and a compressed Raspberry Pi 4+ arm64 SD/USB/NVMe image with every release.
* Build all installation images directly in GitHub Actions from the exact release commit.
### Security fixes 🔒
* Pin the Debian amd64 base image by immutable URL and SHA-256 digest for reproducible release builds.
* Publish per-image checksums and provenance manifests plus a signed aggregate image manifest; release publication is blocked unless every image validates and stays within GitHub's asset-size limit.
### Operational notes 🔔
* The x64 ISO supports BIOS and UEFI boot. The Raspberry Pi artifact is intended for direct flashing to SD, USB, or NVMe media.

## 2026.10.5
### Fixes 🐞
* Publish the final Host Settings layout on a forward-only version so appliances running `2026.10.4-rc.1` can return to the stable channel without manual intervention.

## 2026.10.4
### Fixes 🐞
* Separate Host Identity and Timezone controls into two full-width rows for clearer administration.
* Treat a final stable version as newer than its matching release candidate during channel transitions.

## 2026.10.4-rc.1
### Fixes 🐞
* Separate Host Identity and Timezone controls into two full-width rows for clearer administration.

## 2026.10.3
### New features ✨
* Render signed release notes as safe, structured markup in both the overview and update confirmation dialog.
* Show only release-note sections newer than the installed version through the selected available release.
### Fixes 🐞
* Move update-channel controls into the Release Channel status card.
* Reorder operational panels as Host Settings, TLS Trust, MQTT Service, Backups, and Restore.
* Keep help controls beside their headings and make panel actions wrap within the viewport across desktop and mobile breakpoints.
* Improve select, release-note, dialog, and control-group styling for a more consistent administration console.
### Security fixes 🔒
* Render release-note markup with DOM text nodes and an allowlisted parser; raw HTML is never interpreted.

## 2026.10.2
### Breaking changes 🚨
* none
### New features ✨
* Select the signed `stable` or `prerelease` appliance update channel from the authenticated web console.
* Show the configured update channel separately from release availability.
### Security fixes 🔒
* Restrict channel changes end to end to two allowlisted values and exact passwordless-sudo command lines.
* Continue requiring Minisign verification and signed checksums for releases discovered through either channel.
### Fixes 🐞
* Replace legacy manual prerelease URL configuration with an atomic, audited channel setting while preserving existing pinned installations for compatibility.
### Operational notes 🔔
* Existing appliances first update normally to `2026.10.1`; channel selection becomes available after that update and the subsequent `2026.10.2` installation.

## 2026.10.1
### Breaking changes 🚨
* Production OpenBridgeServer and Mosquitto images are now pinned to reviewed immutable digests. The legacy `OBS_IMAGE_TAG` environment override is no longer applied; installations that intentionally used a custom OBS image must review the pinned image before updating.
### New features ✨
* Show the running OpenBridgeServer version in the appliance console.
* Publish the reviewed Minisign release verification key with release assets.
### Security fixes 🔒
* Reject unsafe, ambiguous, oversized, linked, and special-file archive members before privileged extraction.
* Rate-limit failed administrator logins per verified client address.
* Require a locally generated one-time token before the initial administrator password can be set.
* Pin production container images and the CI checkout action to immutable digests or commits.
* Serialize one-time onboarding, reject untrusted forwarded-address headers, and create onboarding state files without following symlinks.
* Move the nginx-to-agent connection to a private Unix socket.
* Enable HSTS, a scoped Content Security Policy for `/obos`, and modern AEAD-only TLS 1.2 cipher suites.
### Fixes 🐞
* Allow first-boot provisioning to export headless onboarding information to supported boot partitions under the systemd sandbox.
* Add regression coverage for archive extraction, login throttling, concurrent onboarding, proxy-header spoofing, and release pinning.
### Operational notes 🔔
* Existing appliances reboot after installation so the new agent socket, nginx routing, and service sandbox take effect together. The installer validates and stages the new nginx configuration without replacing the active configuration; first-boot activation is therefore coordinated with the reboot and falls back to the prior TCP-compatible pair if full validation fails.
* OpenBridgeServer browser-token storage remains an upstream hardening item.

### Release verification
* Minisign public key ID: `1D3C747967BE7F02`
* Public key: `RWQCf75neXQ8HR0B7VAbOhEJ/3A/iL7BKj/3+l/4gZ+Z+aqazNEcMW/I`

## 2026.10.0
### Breaking changes 🚨
* none
### New features ✨
* Initial Release
### Fixes 🐞
* none
### Known Issues 🔔
* none

### Release verification
* Minisign public key ID: `1D3C747967BE7F02`
* Public key: `RWQCf75neXQ8HR0B7VAbOhEJ/3A/iL7BKj/3+l/4gZ+Z+aqazNEcMW/I`
