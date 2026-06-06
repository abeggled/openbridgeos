# Release Signing Policy

open bridge operating system release bundles use detached Minisign signatures for
the release manifest. The release manifest then pins each image artifact,
checksum file, image manifest, and artifact hash.

This policy defines the technical MVP handling rules for release signing keys
and publication.

## Key Roles

- Release private key: signs release manifests only.
- Release public key: distributed through documentation and release notes so
  users can verify release manifests.
- Build host: creates images, checksums, image manifests, and the release
  manifest.
- Signing host: holds the private key and signs only validated release manifests.

The build host and signing host may be the same for early test builds, but the
private key must not be copied into image build directories, generated images, or
release archives.

## Private Key Rules

- Store the private key encrypted at rest.
- Keep the private key outside this repository.
- Keep the private key outside `build/` and `dist/`.
- Do not inject the private key into CI for the technical MVP.
- Do not copy the private key to test appliances.
- Rotate the key if it is copied to an untrusted system or exposed in logs.

## Signing Flow

1. Build images with `OBOS_RELEASE_BUILD=1`.
2. Validate each image manifest with strict file checks.
3. Create the release manifest.
4. Validate the release manifest with strict file and signature-file checks.
5. Sign the release manifest on the signing host.
6. Validate the detached signature with the release public key.
7. Publish images, checksum files, image manifests, release manifest, detached
   signature, public key, and validation records together.

Example signing command:

```sh
minisign -Sm dist/images/obos-release.manifest
```

Example verification command:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  OBOS_RELEASE_SIGNATURE_STRICT=1 \
  OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

After image validation records are completed, run the release candidate gate:

```sh
OBOS_RELEASE_MINISIGN_PUBLIC_KEY='<minisign-public-key>' \
  sh scripts/images/check-release-candidate.sh \
    dist/images/obos-release.manifest \
    validation-amd64-vm.record \
    validation-rpi4-arm64.record
```

## Publication Gate

Publish a technical MVP release candidate only when:

- release manifest verification passes with the public key
- artifact checksums match the release manifest
- image manifests record `release_build=1`
- image manifests record `repo_dirty=false`
- image validation records pass
- `check-release-candidate.sh` cross-checks validation records against the
  release manifest
- broad release publication runs the Compose image pinning check with
  `OBOS_REQUIRE_PINNED_IMAGES=1`
- the release public key is included in release notes

## Rotation

When rotating the release key:

1. Generate a new Minisign key pair offline.
2. Publish the new public key with a clear effective release candidate.
3. Keep old public keys available for old releases.
4. Sign new release manifests with only the new private key after the effective
   release candidate.
5. Document the old and new public key fingerprints in release notes.
