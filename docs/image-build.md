# Image Build Plan

Open Bridge OS should ship as ready-to-boot artifacts, not as instructions users
must assemble manually.

## Artifacts

Planned artifacts:

- `amd64` VM image for Proxmox, Hyper-V, VirtualBox, and bare-metal testing
- `amd64` ISO or installer image
- `arm64` Raspberry Pi 4+ SD/USB image

## Build Principles

- Secrets are never generated during image build.
- First boot performs per-appliance-instance initialization.
- Build output includes checksums.
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
amd64-vm.env      Debian Trixie amd64 VM image profile, planned qcow2 output
rpi4-arm64.env    Debian Trixie arm64 Raspberry Pi 4+ image profile, planned raw output
```

Profiles are shell-style key-value files that describe the build target without
starting a build. Required keys include architecture, image kind, Debian release,
boot target, output format, base packages, shared provision script, and first
boot service.

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
7. Emit the image artifact plus checksum.

The first implementation should turn the `amd64-vm` profile into a bootable
qcow2 image. The Raspberry Pi profile should follow once firmware and boot
partition handling are explicit and repeatable.

## First Implementation Direction

Start with a Debian 13 `amd64` qcow2 development image. Once that boots and
starts Open Bridge Server reliably, add the Raspberry Pi image path.

The build system should call:

```sh
scripts/bootstrap/provision-debian.sh /path/to/openbridgeos
```

inside the target filesystem or VM during image creation.

## Open Questions

- Use Packer, Debian live-build, or debos for the first image builder?
- Should Raspberry Pi images use pure Debian or Raspberry Pi OS Lite 64-bit as
  the base while keeping the userland aligned with Debian 13?
- Should the default image enable SSH for development builds only?
- How should users recover if first boot cannot reach the network to pull the
  Open Bridge Server image?
