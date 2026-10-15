# Changes
## 2026.10.7-rc.4
### Fixes 🐞
* Apply hostname, console-keyboard, and NTP configuration through narrowly scoped synchronous transient units, so the hardened web agent no longer needs to create temporary files in read-only `/etc` parent directories.
* Report a host-setting change as complete only after its managed configuration file has been written successfully; a failed hostname action can no longer appear to complete during a later timezone refresh.
### Operational notes 🔔
* Debian 13 continues to use its supported 6.12 kernel series. OBOS installs Debian security and stable updates for that series instead of opting appliances into the non-default backports kernel line.

## 2026.10.7-rc.3
### Fixes 🐞
* Prepare the managed `systemd-networkd` and `systemd-timesyncd` directories before the hardened web agent starts, so NTP changes no longer fail on a missing read-only path.
* Replace free-text keyboard entry with a dropdown populated from the installed Debian XKB layouts. Persist the selected XKB layout and apply it to the Linux console through `setupcon`.
* Store the complete appliance-update log below the writable OBOS state directory instead of `/var/log`, preventing update startup from failing inside the hardened agent service.
* Fully deconfigure and reactivate the managed interface when switching from DHCP to static addressing, removing the previous DHCP address instead of retaining it as a secondary address.
* Renew the HTTPS leaf certificate automatically after a network change and, for static mode, include only addresses declared in the managed network configuration.
### Operational notes 🔔
* RC.2 installations affected by the update-log write restriction require a one-time repair of the currently running service before the GUI can install RC.3. Fresh RC.3 installations and later in-place updates do not require this workaround.

## 2026.10.7-rc.2
### Fixes 🐞
* Separate DHCP and static addressing in **Host Settings**. The detected interface is read-only; IP address, subnet mask, gateway, and DNS are shown only for static mode.
* Apply network settings successfully from the hardened web agent by granting narrowly scoped write access to the managed network and time configuration paths.
* Keep `/etc/hosts` synchronized when the appliance hostname changes, preventing `sudo: unable to resolve host` warnings.
* Install and activate `systemd-resolved`, connect `/etc/resolv.conf` to its local stub, and apply validated static DNS settings to the running system.
### Security fixes 🔒
* Validate the IPv4 address and dotted subnet mask together, reject network or broadcast addresses, require a gateway inside the selected subnet, and require at least one valid DNS server for static mode.
### Operational notes 🔔
* Applying a network change is delayed by three seconds and can disconnect the browser. Reopen the appliance at its newly configured address.

## 2026.10.7-rc.1
### New features ✨
* Configure console keyboard layout, DHCP or static IP addressing, gateway, DNS, and NTP directly in **Host Settings**.
* View the complete most recent appliance-update attempt, including Debian APT output, in authenticated **System Diagnostics**.
### Fixes 🐞
* Make Debian package maintenance explicit and observable: every appliance update refreshes signed Debian metadata, installs required host-management packages, and runs a protected full upgrade before container health verification.
### Security fixes 🔒
* Validate network, DNS, NTP, interface, and keyboard inputs on both sides of the local agent boundary; apply network changes asynchronously after explicit confirmation to avoid exposing a general shell interface.
### Operational notes 🔔
* A static address change can disconnect the current browser session. Continue at the newly configured IP address after the three-second apply delay.

## 2026.10.6
### New features ✨
* Publish a bootable amd64 installer ISO, an amd64 qcow2 VM disk, and a compressed Raspberry Pi 4+ arm64 image with every release.
* Run the amd64 installer automatically on single-disk systems, including partitioning and GRUB installation after one explicit destructive confirmation.
* Generate unique per-device passwords for the Linux `root` and `obos` recovery users, show the `obos` password and appliance IP address before reboot, and allow authenticated reveal or rotation in System Diagnostics.
### Security fixes 🔒
* Sign the aggregate image manifest and publish checksums and provenance manifests for every installation image.
* Keep first-boot provisioning sandboxed while granting only its `/etc/obos` state directory explicit write access; Linux password initialization runs in a separate ordered one-shot service.
* Remove recovery credentials from normal status, logs, release bundles, and backups while auditing reveal and rotation operations without recording secrets.
### Fixes 🐞
* Complete browser-only first login without requiring a console setup token.
* Preserve Python, nginx, and the complete shared runtime package set in installed ISO systems.
* Configure `pool.ntp.org`, suppress installer account questions, and install GRUB on the automatically selected whole disk.
* Prevent stale installer `cdrom:` sources from blocking in-place updates and isolate privileged host updates to signed Debian HTTPS sources.
* Fix first-boot TLS provisioning and the resulting nginx `BIO_new_file()` failure after ISO installation.
### Operational notes 🔔
* This stable release supersedes all `2026.10.6-rc.*` builds. Systems installed with RC.6 or earlier should be reinstalled with the stable ISO; no console repair is required.

## 2026.10.6-rc.7
### Fixes 🐞
* Allow first-boot provisioning to write explicitly below `/etc/obos` while retaining the read-only system configuration sandbox everywhere else.
* Initialize per-device Linux recovery credentials in a dedicated ordered one-shot service before TLS and web onboarding provisioning begins.
* Prevent the missing first-boot TLS material that caused nginx startup to fail with `BIO_new_file()` after an ISO installation.
### Security fixes 🔒
* Replace the ineffective broad `/etc` sandbox exception with the narrow `/etc/obos` exception in the long-lived first-boot policy; only the short credential initializer can update passwd and shadow files.
### Operational notes 🔔
* RC.6 installations affected by the first-boot failure should be reinstalled with the RC.7 ISO; no console repair is required.

## 2026.10.6-rc.6
### Fixes 🐞
* Suppress Debian Installer account and password questions while retaining per-device recovery credentials generated on the target system.
* Configure `pool.ntp.org` automatically during installation.
* Install GRUB on the automatically selected whole disk without asking for a disk or partition again.
* Show the current DHCP IPv4 address and direct web-console URL alongside the `obos` recovery password before reboot.
### Operational notes 🔔
* Automatic installation still stops safely when zero or multiple eligible internal disks are present; only the single-disk path is fully unattended after its destructive confirmation.

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
