# Technical MVP Handoff

This checklist is the short handoff path for preparing open bridge operating
system technical MVP test devices.

It does not replace the detailed build, signing, security, and validation
documents. It gives the operator one ordered path from repository state to
validated test images.

## Inputs

Required before starting:

- clean `main` checkout
- Debian build host for image creation
- release signing public key
- release signing private key on the signing host
- one VM target for `amd64-vm`
- one Raspberry Pi 4 or newer target
- Raspberry Pi Network Installer path available
- administrator client for TLS trust onboarding
- release notes prepared from
  [release-notes-template.md](release-notes-template.md)

## Build

Run profile and build-host preflights:

```sh
sh scripts/images/validate-image-profiles.sh
sh scripts/images/check-amd64-qcow2-build-host.sh
sudo sh scripts/images/check-rpi4-arm64-build-host.sh
```

Build release images:

```sh
sudo OBOS_RELEASE_BUILD=1 \
  OBOS_QCOW2_BASE_IMAGE_SHA256='<base-image-sha256>' \
  scripts/images/build-amd64-qcow2.sh

sudo OBOS_RELEASE_BUILD=1 \
  scripts/images/build-rpi4-arm64-image.sh
```

## Bundle And Sign

Create and verify the release manifest:

```sh
sh scripts/images/create-release-manifest.sh \
  dist/images/obos-release.manifest \
  dist/images/obos-amd64-vm-latest.qcow2.manifest \
  dist/images/obos-rpi4-arm64-latest.img.xz.manifest

OBOS_MANIFEST_STRICT_FILES=1 \
  OBOS_RELEASE_SIGNATURE_STRICT=1 \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

Sign on the signing host:

```sh
minisign -Sm dist/images/obos-release.manifest
```

Verify with the public key:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  OBOS_RELEASE_SIGNATURE_STRICT=1 \
  OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

## Validate Images

Run the qcow2 smoke test:

```sh
sudo scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

Run the Raspberry Pi Network Installer validation described in
[image-release-validation.md](image-release-validation.md).

Create one validation record per profile and check each record:

```sh
sh scripts/images/check-image-release-validation-record.sh validation-amd64-vm.record
sh scripts/images/check-image-release-validation-record.sh validation-rpi4-arm64.record
```

Check the complete release candidate:

```sh
OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-candidate.sh \
    dist/images/obos-release.manifest \
    validation-amd64-vm.record \
    validation-rpi4-arm64.record
```

For broad release publication, additionally require pinned Compose images:

```sh
OBOS_REQUIRE_PINNED_IMAGES=1 \
  sh scripts/images/check-compose-image-pinning.sh apps/openbridgeserver/compose.yaml
```

Complete release notes from [release-notes-template.md](release-notes-template.md)
and attach the release public key, validation records, known gaps, and migration
notes.

## Runtime Acceptance

On each test appliance, run:

```sh
sudo obosctl status
sudo obosctl security-summary
sudo obosctl mvp-readiness-summary
```

The technical MVP test device is acceptable when:

- `security-summary` reports `result=PASS`
- `mvp-readiness-summary` reports `result=PASS`
- HTTPS web console is reachable after trust onboarding
- MQTT remains localhost-only unless explicitly enabled
- backup creation, rollback staging, and restore apply planning pass
- release candidate gate passes with records matching the release manifest

## Blocking Conditions

Do not hand off the image if any of these are true:

- release manifest signature cannot be verified with the public key
- image validation records do not match the release manifest
- `CONFIG_BLK_DEV_NVME=y` is missing for Raspberry Pi images
- Raspberry Pi Network Installer path was not validated
- first boot generated secrets during image build instead of on first boot
- SSH is enabled by default
- security or MVP readiness summaries fail
- raw unencrypted backups are used for web download or migration
