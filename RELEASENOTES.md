# Changes
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
