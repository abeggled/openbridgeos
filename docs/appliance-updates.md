# Appliance Updates

The confirmed `obosctl update` and web-console **Update Appliance** action update
the appliance as one maintained product. The workflow runs in this order:

1. Stop OBS and create a consistent OBS data/configuration backup.
2. Query the latest GitHub release for a signed OBOS in-place update bundle.
3. Verify the pinned Minisign trust key, manifest signature, archive checksum,
   version, archive paths, and archive file types before installing OBOS files.
4. Refresh APT metadata and fully upgrade installed Debian packages without
   allowing automatic package removals.
5. Pull the container images defined by the installed OBOS release.
6. Start OBS and verify localhost plus HTTPS health.
7. Record the complete result and schedule a reboot after 60 seconds when a
   package marker, newer kernel, or installed OBOS release requires it.

The OBS backup supports application-data recovery. It does not roll back Debian
packages or installed OBOS system files. A future A/B system design would be
required for atomic whole-system rollback.

Release changes that must become active together at boot, such as a coordinated
agent-listener and nginx-upstream migration, are validated and staged below
`/etc/obos/update/`. `obos-first-boot.service` activates the pending nginx
configuration before nginx starts. The currently running proxy configuration is
left untouched throughout download, package upgrades, and health checks.

## GitHub Release Assets

An updatable GitHub release publishes these assets with fixed names:

```text
obos-update.tar.gz
obos-update.manifest
obos-update.manifest.minisig
obos-update-notes.txt
obos-release.minisign.pub
```

Create the archive and manifest from a clean tagged checkout:

```sh
sh scripts/update/create-update-bundle.sh 2026.10.0 dist/update RELEASENOTES.md
minisign -Sm dist/update/obos-update.manifest
```

The manifest uses `obos-update-release-v1` and pins the release version, Git
revision, archive filename, SHA-256 checksum, archive root directory, release
notes filename, and release-notes checksum. The web console verifies the
signature and release-notes checksum before showing the notes. It displays the
available version and notes before the administrator confirms an update.

The text entered as the GitHub Release description should match
`obos-update-notes.txt`, so the GitHub page and appliance console communicate
the same changes. The downloadable notes asset is authoritative for the
appliance because its checksum is covered by the signed manifest.

Create the tag from the exact clean commit used to produce the archive. Publish
all five fixed-name assets in one release. A draft
release is recommended until an upgrade from the previous appliance version has
passed on the MVP VM.

For an end-to-end MVP test without changing the stable `latest` channel, publish
`2026.10.0` as a GitHub prerelease and put this exact single line in
`/etc/obos/update/release-base-url` on the MVP appliance:

```text
https://github.com/abeggled/openbridgeos/releases/download/2026.10.0
```

The updater accepts only the official `abeggled/openbridgeos` GitHub release
path from that file. After the MVP upgrade passes, promote the same release to a
normal release and remove the override file; subsequent appliances use
`releases/latest/download` again.

## GitHub Release Workflow

The manually dispatched `Release appliance update` workflow builds, signs,
verifies, and publishes the fixed-name assets from the selected `main` commit.
It uses the GitHub environment `release` and requires this environment secret:

```text
OBOS_RELEASE_MINISIGN_SECRET_KEY
```

This is a dedicated passwordless Minisign automation key generated with `-W`.
GitHub stores the private key as an encrypted environment secret; it is never
committed to the repository or copied to an appliance. Personal and offline
release keys are not used by the workflow.

The workflow refuses to replace an existing tag or release. Start it from the
GitHub Actions page with the exact version and keep `prerelease` enabled for the
MVP validation run.

## Trust Bootstrap

The release signing public key must be pinned in the appliance image; it is
never learned from GitHub at update time. Provide it to provisioning as
`OBOS_RELEASE_MINISIGN_PUBLIC_KEY`, or place the reviewed public key at
`packaging/update/obos-release.minisign.pub` before building an image. The
installed trust anchor is `/etc/obos/update/minisign.pub`.

If no key is pinned, the release step reports `not-configured` and does not
download or execute release content. Debian and container update stages can
still proceed, but the GUI marks the OBOS release state as a deviation.

Release signing keys must follow
[release-signing.md](release-signing.md).
