# Image Release Validation

This runbook defines the technical MVP validation for open bridge operating
system image artifacts before they are used on test devices.

Release validation is separate from CI fixtures. CI verifies contracts and
static checks; this runbook verifies that generated images boot, initialize the
appliance instance, keep hardening defaults, and expose the expected recovery
paths on real or VM hardware.

## Scope

Validate every release candidate for these profiles:

- `amd64-vm` qcow2 image
- `rpi4-arm64` compressed raw image for Raspberry Pi Network Installer

Each validated release candidate must have:

- image artifact
- checksum file
- image manifest
- release manifest
- release signature

## Artifact Integrity

Before booting an image:

1. Verify the release manifest signature.
2. Verify every artifact checksum listed in the release manifest.
3. Verify the image manifest profile, architecture, output format, and Debian
   release.
4. Verify `contains_secrets=false`.
5. Verify `first_boot_pending=true`.
6. Verify `ssh_default=disabled`.

The Raspberry Pi image manifest must additionally record:

- `network_installer_compatible=true`
- `boot_media=sd,usb,nvme`
- `kernel_config_verified=true`
- `CONFIG_BLK_DEV_NVME=y`
- `boot_partition_label=OBOSBOOT`
- `root_partition_label=OBOSROOT`

## amd64 VM Validation

Validate the qcow2 image in at least one supported VM environment before the
technical MVP is declared ready for test devices.

Minimum VM checks:

1. Boot the image without injecting secrets.
2. Confirm first boot completes and clears the first boot pending marker.
3. Confirm `obos-first-boot.service` completed successfully.
4. Confirm `obos-openbridgeserver.service` is active after network online.
5. Run `sudo obosctl status`.
6. Run `sudo obosctl proxy-health`.
7. Run `sudo obosctl security-summary`.
8. Run `sudo obosctl mvp-readiness-summary`.
9. Run `sudo obosctl tls-renew-leaf-plan`.
10. Export TLS trust material with `sudo obosctl tls-export`.
11. Verify browser access to the web console over HTTPS.

The automated qcow2 smoke test may be used as the first validation pass:

```sh
sudo scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

## Raspberry Pi Validation

Validate the Raspberry Pi image on Raspberry Pi 4 or newer hardware before the
technical MVP is declared ready for test devices.

Minimum Raspberry Pi checks:

1. Deploy the compressed raw image through Raspberry Pi Network Installer.
2. Boot once from SD, USB, or NVMe according to the release target.
3. Confirm first boot completes and clears the first boot pending marker.
4. Confirm `obos-first-boot.service` completed successfully.
5. Confirm `obos-openbridgeserver.service` is active after network online.
6. Confirm SSH is disabled by default.
7. Confirm the boot partition is writable for public TLS trust export.
8. Run `sudo obosctl tls-export-boot`.
9. Verify `OBOS-TRUST.txt`, `OBOS-LOCAL-CA.crt`, and `OBOS-ONBOARDING.txt`
   appear on the boot partition.
10. Run `sudo obosctl security-summary`.
11. Run `sudo obosctl mvp-readiness-summary`.
12. Run `sudo obosctl tls-renew-leaf-plan`.

At least one Raspberry Pi validation run must cover NVMe-capable boot media or
Network Installer deployment. The release is blocked if the kernel config no
longer includes `CONFIG_BLK_DEV_NVME=y`.

## Recovery Drill

Run one recovery drill before publishing a technical MVP test image:

1. Create a backup with `sudo obosctl backup`.
2. Run `sudo obosctl update`.
3. Run `sudo obosctl update-rollback-plan`.
4. Run `sudo obosctl update-rollback-stage`.
5. Inspect the stage with `sudo obosctl restore-stage-inspect <stage-dir>`.
6. Print the apply plan with `sudo obosctl restore-apply-plan <stage-dir>`.

The drill may stop before `restore-apply` for the first technical MVP, but the
apply plan must pass and show that live apply remains a local CLI-only action.

## Trust Onboarding

Run client trust validation with [client-ca-trust.md](client-ca-trust.md) for at
least one administrator workstation used during release validation.

Minimum trust checks:

- verify the local CA SHA-256 fingerprint before import
- access the web console over HTTPS without certificate warnings after import
- remove `OBOS-ONBOARDING.txt` from removable or boot-accessible media after
  onboarding

## Validation Matrix

Record every release validation run:

```text
format=obos-image-release-validation-v1
release_candidate=
profile=
artifact=
manifest=
signature_verified=yes|no
checksums_verified=yes|no
platform=
hardware_or_vm=
boot_media=
network_installer_used=yes|no
first_boot_completed=yes|no
ssh_default_disabled=yes|no
security_summary_result=PASS|FAIL
mvp_readiness_result=PASS|FAIL
tls_leaf_renewal_plan_result=PASS|FAIL
tls_trust_exported=yes|no
rollback_stage_result=PASS|FAIL|not_run
notes=
```

Print a profile-specific validation record template:

```sh
sh scripts/images/print-image-validation-record-template.sh amd64-vm > validation-amd64-vm.record
sh scripts/images/print-image-validation-record-template.sh rpi4-arm64 > validation-rpi4-arm64.record
```

Generated templates are intentionally unfinished. Replace every `<...>`
placeholder after the validation run; the record checker rejects unfinished
templates.

Validate a completed record before attaching it to a release:

```sh
sh scripts/images/check-image-release-validation-record.sh validation.record
```

Validate the complete release candidate before publication:

```sh
sh scripts/images/check-release-candidate.sh \
  dist/images/obos-release.manifest \
  validation-amd64-vm.record \
  validation-rpi4-arm64.record
```

## Release Gate

A technical MVP test image is ready only when:

- release artifact integrity passes
- the qcow2 image passes VM validation
- the Raspberry Pi image passes hardware validation
- Raspberry Pi Network Installer compatibility is validated
- the recovery drill reaches a passing restore apply plan
- client trust onboarding is validated for at least one administrator client
- `check-release-candidate.sh` passes with the release manifest and validation
  records for `amd64-vm` and `rpi4-arm64`

For broad release publication, also run
`OBOS_REQUIRE_PINNED_IMAGES=1 scripts/images/check-compose-image-pinning.sh` so
Compose images must be pinned by digest.
