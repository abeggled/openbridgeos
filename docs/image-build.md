# Image Build Plan

open bridge operating system should ship as ready-to-boot artifacts, not as instructions users
must assemble manually.

## Artifacts

Planned artifacts:

- `amd64` VM image for Proxmox, Hyper-V, VirtualBox, and bare-metal testing
- `amd64` ISO or installer image
- `arm64` Raspberry Pi 4+ SD/USB/NVMe image

## Build Principles

- Secrets are never generated during image build.
- First boot performs per-appliance-instance initialization.
- Hardware sizing, power, storage, and cooling requirements are documented in
  [hardware.md](hardware.md).
- Build output includes checksums.
- Build output includes a manifest for provenance and support triage.
- Release artifacts should be signed before public distribution.
- The same provisioning scripts should be used for manual installs and images.
- Image profiles are validated in CI before any image builder is wired in.

## Image Profiles

The first build foundation is a small profile contract below:

```text
packaging/images/profiles/
```

Current profiles:

```text
amd64-vm.env      Debian Trixie amd64 VM image profile, qcow2 output
rpi4-arm64.env    Debian Trixie arm64 Raspberry Pi 4+ image profile, raw img.xz output
```

Profiles are shell-style key-value files that describe the build target. Required
keys include architecture, image kind, Debian release, boot target, output
format, base packages, shared provision script, and first boot service.

The `amd64-vm` profile also declares the Debian genericcloud qcow2 base image,
minimum output size, required builder tooling, and the default SSH policy.

Raspberry Pi profiles also declare:

- Raspberry Pi Network Installer compatibility
- Debian components `main,non-free-firmware`
- boot packages `linux-image-arm64`, `raspi-firmware`, and `initramfs-tools`
- compressed raw `.img.xz` output
- supported boot media: SD, USB, and NVMe
- Raspberry Pi bootloader firmware mode
- disabled SSH default policy
- boot/root partition layout and labels
- required build host tooling
- required kernel config flags

For the `rpi4-arm64` profile, `CONFIG_BLK_DEV_NVME=y` is a hard requirement so
NVMe boot/install targets remain supported. The current profile also requires
`CONFIG_PCIE_BRCMSTB=y` and `CONFIG_USB_XHCI_PCI=y` because those are part of
the intended Raspberry Pi 4+ storage path.

Validate profiles with:

```sh
sh scripts/images/validate-image-profiles.sh
```

Print the current build contract for a profile with:

```sh
sh scripts/images/print-image-build-plan.sh packaging/images/profiles/amd64-vm.env
sh scripts/images/print-image-build-plan.sh packaging/images/profiles/rpi4-arm64.env
```

## Build Contract

Every image builder must follow the same contract:

1. Create a Debian 13 Trixie root filesystem for the target architecture.
2. Install the profile base packages.
3. Copy this repository into the image build context.
4. Run `scripts/bootstrap/provision-debian.sh` inside the target filesystem or VM.
5. Do not run first boot during image creation.
6. Enable `obos-first-boot.service` for target appliance initialization.
7. Keep first boot and managed container startup ordered after
   `network-online.target`.
8. Emit the image artifact plus checksum and manifest.

Raspberry Pi image builders must additionally:

1. Produce a compressed raw `.img.xz` image that Raspberry Pi Network Installer can deploy.
2. Use Debian `main,non-free-firmware` components for Raspberry Pi firmware.
3. Install the profile boot packages into the target root filesystem.
4. Use a `boot-fat32,root-ext4` partition layout.
5. Label the boot partition `OBOSBOOT` and the root partition `OBOSROOT`.
6. Preserve compatibility with SD, USB, and NVMe boot media.
7. Verify the kernel config contract before publishing artifacts.
8. Keep `CONFIG_BLK_DEV_NVME=y` enabled for every release image.
9. Let first boot export public TLS trust material to the mounted boot partition
   when a writable boot partition is available.

## amd64 qcow2 Builder

The first qcow2 builder customizes the Debian 13 genericcloud amd64 image using
`virt-customize`. It is intended for local development and VM smoke tests before
release automation is added.

Install builder dependencies on a Debian build host:

```sh
sudo apt-get install --no-install-recommends qemu-utils libguestfs-tools curl ca-certificates
```

Check the build host before starting a long image build:

```sh
sh scripts/images/check-amd64-qcow2-build-host.sh
```

The preflight validates the `amd64-vm` profile, required qcow2 tools, basic
`qemu-img` and `virt-customize` responsiveness, and reports whether `/dev/kvm` is
available. Missing KVM is a warning because QEMU can fall back to slower TCG
emulation for smoke tests.

Build the image:

```sh
sudo scripts/images/build-amd64-qcow2.sh
```

By default the script:

1. validates the `amd64-vm` profile with the shared image profile validator
2. downloads the Debian Trixie genericcloud amd64 qcow2 base image if no local base is provided
3. copies it to `dist/images/obos-amd64-vm-<timestamp>.qcow2`
4. resizes it to the profile minimum size
5. copies the repository into `/opt/openbridgeos` inside the image
6. runs `scripts/bootstrap/provision-debian.sh` inside the image with SSH disabled
7. keeps first boot pending for the target appliance instance
8. cleans machine identity and logs with `virt-sysprep`
9. writes `.sha256` and `.manifest` files next to the image

Use a pre-downloaded base image when needed:

```sh
sudo OBOS_QCOW2_BASE_IMAGE=/srv/images/debian-13-genericcloud-amd64.qcow2 \
  scripts/images/build-amd64-qcow2.sh
```

Pin the base image hash for release builds or controlled build hosts:

```sh
sudo OBOS_QCOW2_BASE_IMAGE=/srv/images/debian-13-genericcloud-amd64.qcow2 \
  OBOS_QCOW2_BASE_IMAGE_SHA256=<expected-sha256> \
  scripts/images/build-amd64-qcow2.sh
```

When `OBOS_QCOW2_BASE_IMAGE_SHA256` is set, the builder fails before image
customization if the downloaded or supplied base image hash does not match.

For release artifacts, set `OBOS_RELEASE_BUILD=1`. Release builds require
`OBOS_QCOW2_BASE_IMAGE_SHA256` and record `release_build=1` in the manifest:

```sh
sudo OBOS_RELEASE_BUILD=1 \
  OBOS_QCOW2_BASE_IMAGE=/srv/images/debian-13-genericcloud-amd64.qcow2 \
  OBOS_QCOW2_BASE_IMAGE_SHA256=<expected-sha256> \
  scripts/images/build-amd64-qcow2.sh
```

The qcow2 manifest uses format `obos-qcow2-build-v1` and records:

- image profile, architecture, Debian release, and output format
- whether the artifact was built as a release build
- image path, checksum file, and SHA-256 hash
- base image path, source URL, and SHA-256 hash
- provision script and first boot service
- repository revision when available
- repository dirty state
- SSH default policy
- `first_boot_pending=true`
- `contains_secrets=false`

Image builds must not generate appliance secrets. Secrets, appliance identifier,
and TLS material are created only by first boot on the target appliance instance.

Validate a manifest after building:

```sh
sh scripts/images/check-qcow2-manifest.sh dist/images/obos-amd64-vm-latest.qcow2.manifest
```

Use strict file verification when the referenced image, checksum file, and base
image are present on the same build host:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/check-qcow2-manifest.sh dist/images/obos-amd64-vm-latest.qcow2.manifest
```

Local build outputs are ignored by git via `build/`, `dist/`, and `*.qcow2`.

## Raspberry Pi arm64 Image

The `rpi4-arm64` profile targets Raspberry Pi 4 and newer boards with Debian 13
Trixie arm64 userland. The intended publishable artifact is a compressed raw
image ending in `.img.xz`, suitable for Raspberry Pi Network Installer style
deployment and manual flashing.

Before publishing or installing Raspberry Pi images, check the power, cooling,
storage, and recovery expectations in [hardware.md](hardware.md). In particular,
production appliances should use reliable power and storage media, and NVMe boot
support must remain part of the release image contract.

The contract requires:

- architecture: `arm64`
- Debian components: `main,non-free-firmware`
- boot packages: `linux-image-arm64`, `raspi-firmware`, `initramfs-tools`
- output: raw image compressed with `xz`, extension `.img.xz`
- minimum image size: `8G`
- partition layout: `boot-fat32,root-ext4`
- partition labels: `OBOSBOOT` and `OBOSROOT`
- boot media: SD, USB, and NVMe
- SSH disabled by default
- required kernel config: `CONFIG_BLK_DEV_NVME=y`, `CONFIG_PCIE_BRCMSTB=y`, and `CONFIG_USB_XHCI_PCI=y`

Check the current Raspberry Pi build contract with:

```sh
sh scripts/images/print-image-build-plan.sh packaging/images/profiles/rpi4-arm64.env
```

Install build host dependencies on Debian:

```sh
sudo apt-get install --no-install-recommends \
  debootstrap qemu-user-static dosfstools e2fsprogs fdisk xz-utils mount util-linux parted tar
```

Check the build host before starting an image build:

```sh
sh scripts/images/check-rpi4-arm64-build-host.sh
```

The preflight validates the `rpi4-arm64` profile, required build tools, root
status, `qemu-aarch64` binfmt registration, and loop-device availability. Missing
root, binfmt, or loop support is reported as a warning so the script can still be
used for early diagnostics on non-build hosts. The image builder runs this
preflight automatically before it creates or mounts image files.

Build the Raspberry Pi image:

```sh
sudo scripts/images/build-rpi4-arm64-image.sh
```

By default the script:

1. runs the Raspberry Pi build host preflight
2. validates the `rpi4-arm64` profile with the shared image profile validator
3. creates an `8G` raw image with `boot-fat32,root-ext4` partitions
4. bootstraps Debian arm64 using `main,non-free-firmware`
5. installs base packages plus Raspberry Pi boot packages
6. copies this repository into `/opt/openbridgeos` inside the target filesystem
7. runs `scripts/bootstrap/provision-debian.sh` inside the target filesystem with SSH disabled
8. keeps first boot pending for the target appliance instance
9. verifies Raspberry Pi boot files, including partition labels and `rootwait`
10. verifies the kernel config contract, including `CONFIG_BLK_DEV_NVME=y`
11. writes `.img.xz`, `.sha256`, and `.manifest` artifacts
12. validates the generated manifest in strict mode

On first boot, the target appliance tries to write `OBOS-TRUST.txt` and
`OBOS-LOCAL-CA.crt` to a writable mounted boot partition such as
`/boot/firmware`. These files contain only public trust material and are meant
to support headless Raspberry Pi onboarding.

Verify the kernel config from a mounted or extracted Raspberry Pi image before
publishing:

```sh
sh scripts/images/check-rpi-kernel-config.sh /mnt/obos-rpi-root
```

The checker also accepts a direct kernel config file:

```sh
sh scripts/images/check-rpi-kernel-config.sh /mnt/obos-rpi-root/boot/config-6.1.0-rpi-arm64
```

Verify generated Raspberry Pi boot files from a mounted root filesystem:

```sh
sh scripts/images/check-rpi-boot-files.sh /mnt/obos-rpi-root
```

The boot file checker validates `/etc/fstab`, `/boot/config.txt`, and
`/boot/cmdline.txt` against the `rpi4-arm64` profile labels and boot contract.

The Raspberry Pi image manifest uses format `obos-rpi-image-build-v1` and records:

- image profile, architecture, Debian release, and output format
- xz compression and `.img.xz` artifact extension
- whether the artifact was built as a release build
- image path, checksum file, and SHA-256 hash
- Raspberry Pi Network Installer compatibility
- boot media, firmware mode, partition layout, and partition labels
- SSH disabled by default
- required kernel config and whether it was verified
- provision script and first boot service
- repository revision and dirty state
- `first_boot_pending=true`
- `contains_secrets=false`

Validate a Raspberry Pi image manifest after building:

```sh
sh scripts/images/check-rpi-image-manifest.sh dist/images/obos-rpi4-arm64-latest.img.xz.manifest
```

Use strict file verification when the referenced image and checksum file are
present on the same build host:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/check-rpi-image-manifest.sh dist/images/obos-rpi4-arm64-latest.img.xz.manifest
```

## Release Bundle Manifest

Release publishing should create one bundle manifest that references the
individual image manifests:

```sh
sh scripts/images/create-release-manifest.sh \
  dist/images/obos-release.manifest \
  dist/images/obos-amd64-vm-latest.qcow2.manifest \
  dist/images/obos-rpi4-arm64-latest.img.xz.manifest
```

The release bundle manifest uses format `obos-release-bundle-v1` and records:

- creation timestamp and repository revision
- detached signature requirement, signature type, and expected signature file
- artifact count
- each artifact profile, architecture, image path, checksum file, image hash,
  and source image manifest

Only image manifests with `release_build=1` can be added to a release bundle.
The current release signature contract expects a detached Minisign signature at
`<release-manifest>.minisig`. Validate the release bundle before publishing:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

Strict release bundle validation requires each referenced image file, checksum
file, image manifest, and optional base image file to be present on the same
build host. Require the detached signature file during final publication checks:

```sh
OBOS_MANIFEST_STRICT_FILES=1 \
  OBOS_RELEASE_SIGNATURE_STRICT=1 \
  sh scripts/images/check-release-manifest.sh dist/images/obos-release.manifest
```

The builder host must provide the profile tools: `debootstrap`,
`qemu-aarch64-static`, `sfdisk`, `mkfs.vfat`, `mkfs.ext4`, `losetup`, `mount`,
`umount`, `partprobe`, `tar`, `xz`, and `sha256sum`.

## amd64 qcow2 Smoke Test

The smoke test boots a qcow2 image in snapshot mode, forwards host TCP `8443` to
the guest HTTPS port, forwards host TCP `18080` to the guest direct HTTP port,
and waits for the open bridge server health endpoint over HTTPS. After HTTPS
health passes, the test also verifies that direct open bridge server HTTP is not
reachable from the VM network boundary.

Install runtime dependencies on a Linux host:

```sh
sudo apt-get install --no-install-recommends qemu-system-x86 curl
```

Run the smoke test:

```sh
sudo scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

The test deliberately does not require SSH because SSH is disabled by default for
appliance images. It validates the externally visible appliance boundary:

```text
https://127.0.0.1:8443/api/v1/system/health
```

Useful overrides:

```sh
sudo OBOS_SMOKE_HOST_HTTPS_PORT=9443 \
  OBOS_SMOKE_HOST_HTTP_PORT=19080 \
  OBOS_SMOKE_TIMEOUT_SECONDS=1200 \
  scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

## Current Implementation Direction

Validate the `amd64-vm` qcow2 image in a VM first. The smoke test confirms that
first boot generates appliance identity, TLS material, app secrets, and that
`obosctl status` passes through localhost and verified HTTPS proxy health.

Keep the Raspberry Pi builder aligned with the Network Installer compatible
`rpi4-arm64` profile, including the NVMe kernel config requirement and disabled
SSH default.

## Open Questions

- Should the qcow2 builder move from local script to GitHub Actions once artifact size and runner privileges are understood?
- Should Raspberry Pi images continue with pure Debian or use Raspberry Pi OS
  Lite 64-bit while keeping the userland aligned with Debian 13?
- Should development builds have an explicit opt-in SSH profile separate from release images?
- How should users recover if first boot cannot reach the network to pull the
  open bridge server image?
