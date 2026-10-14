# Changes
## 2026.10.1
### Breaking changes 🚨
* none
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
### Known Issues 🔔
* Existing appliances require a reboot after installation so the new agent socket and service sandbox take effect.
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
