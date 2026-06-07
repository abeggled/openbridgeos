# Release Notes Template

Use this template for every open bridge operating system technical MVP release
candidate that is handed to test devices.

The release notes are part of the release evidence. They must be published
together with the images, checksum files, image manifests, release manifest,
detached signature, release public key, and validation records.

Before publication, place the completed notes in the release evidence directory
as `release-notes.md` and run:

```sh
sh scripts/images/check-release-evidence-bundle.sh dist/images
```

## Release

- Release candidate:
- Git commit:
- Release date:
- Target audience:
- Support status: technical MVP test devices only

## Artifacts

List every published artifact:

```text
artifact=
sha256=
manifest=
profile=
```

Required profiles:

- `amd64-vm`
- `rpi4-arm64`

## Signature Verification

Release manifest:

```text
manifest=obos-release.manifest
signature=obos-release.manifest.minisig
release_public_key=obos-release.minisign.pub
minisign_public_key=
minisign_public_key_fingerprint=
signature_verified=yes|no
```

Verification command:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  OBOS_RELEASE_SIGNATURE_STRICT=1 \
  OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

## Validation Records

Attach one passing validation record per required profile:

```text
validation_record=
profile=
artifact=
manifest=
signature_verified=yes|no
checksums_verified=yes|no
network_installer_used=yes|no
security_summary_result=PASS|FAIL
mvp_readiness_result=PASS|FAIL
tls_leaf_renewal_plan_result=PASS|FAIL
rollback_stage_result=PASS|FAIL|not_run
```

Release candidate gate:

```sh
OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-candidate.sh \
    dist/images/obos-release.manifest \
    validation-amd64-vm.record \
    validation-rpi4-arm64.record
```

For broad release publication, record strict Compose image pinning:

```text
compose_image_pinning=PASS|FAIL|not_run
```

## Test Device Acceptance

Summarize the runtime checks from each test appliance:

```text
device=
profile=
boot_media=
security_summary_result=PASS|FAIL
mvp_readiness_result=PASS|FAIL
tls_leaf_renewal_plan_result=PASS|FAIL
tls_trust_onboarding=PASS|FAIL|not_run
mqtt_default=localhost-only|changed
backup_export=PASS|FAIL|not_run
portable_import_stage=PASS|FAIL|not_run
restore_apply_plan=PASS|FAIL|not_run
```

## Known Gaps

List any accepted technical MVP limitations:

- Web restore apply remains CLI-only.
- Network basics beyond hostname and timezone remain future UI work.
- Leaf certificate renewal is implemented as a confirmed CLI-only workflow.
  Local CA rotation and imported public certificate workflows remain follow-up
  work unless explicitly implemented for this release.
- Full disk encryption is not yet part of the technical MVP image baseline.

## Upgrade And Migration Notes

Describe:

- whether this release can update an existing appliance
- whether rollback staging was tested
- how encrypted portable backups can be exported
- how encrypted portable backups can be imported into private staging
- whether any manual operator action is required

## Blocking Issues

Do not publish the release if any item is true:

- release manifest signature cannot be verified
- release public key is missing from these notes
- any required image validation record is missing or fails
- validation records do not match the release manifest
- Raspberry Pi Network Installer validation is missing for `rpi4-arm64`
- `CONFIG_BLK_DEV_NVME=y` is missing for Raspberry Pi images
- runtime `security-summary` or `mvp-readiness-summary` fails
- raw unencrypted backups are offered for web download or migration
