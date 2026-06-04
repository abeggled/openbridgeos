# Image Build Plan

Open Bridge OS should ship as ready-to-boot artifacts, not as instructions users
must assemble manually.

## Artifacts

Planned artifacts:

- `amd64` VM image for Proxmox, Hyper-V, VirtualBox, and bare-metal testing
- `amd64` ISO or installer image
- `arm64` Raspberry Pi 4+ SD/USB/NVMe image

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
amd64-vm.env      Debian Trixie amd64 VM image profile, qcow2 output
rpi4-arm64.env    Debian Trixie arm64 Raspberry Pi 4+ image profile, planned raw output
```

Profiles are shell-style key-value files that describe the build target. Required
keys include architecture, image kind, Debian release, boot target, output
format, base packages, shared provision script, and first boot service.

The `amd64-vm` profile also declares the Debian genericcloud qcow2 base image,
minimum output size, required builder tooling, and the default SSH policy.

Raspberry Pi profiles also declare:

- Raspberry Pi Network Installer compatibility
- supported boot media: SD, USB, and NVMe
- Raspberry Pi bootloader firmware mode
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
7. Emit the image artifact plus checksum.

Raspberry Pi image builders must additionally:

1. Produce an image that Raspberry Pi Network Installer can deploy.
2. Preserve compatibility with SD, USB, and NVMe boot media.
3. Verify the kernel config contract before publishing artifacts.
4. Keep `CONFIG_BLK_DEV_NVME=y` enabled for every release image.

## amd64 qcow2 Builder

The first qcow2 builder customizes the Debian 13 genericcloud amd64 image using
`virt-customize`. It is intended for local development and VM smoke tests before
release automation is added.

Install builder dependencies on a Debian build host:

```sh
sudo apt-get install --no-install-recommends qemu-utils libguestfs-tools curl ca-certificates
```

Build the image:

```sh
sudo scripts/images/build-amd64-qcow2.sh
```

By default the script:

1. downloads the Debian Trixie genericcloud amd64 qcow2 base image if no local base is provided
2. copies it to `dist/images/obos-amd64-vm-<timestamp>.qcow2`
3. resizes it to the profile minimum size
4. copies the repository into `/opt/openbridgeos` inside the image
5. runs `scripts/bootstrap/provision-debian.sh` inside the image with SSH disabled
6. keeps first boot pending for the target appliance instance
7. cleans machine identity and logs with `virt-sysprep`
8. writes a `.sha256` checksum next to the image

Use a pre-downloaded base image when needed:

```sh
sudo OBOS_QCOW2_BASE_IMAGE=/srv/images/debian-13-genericcloud-amd64.qcow2 \
  scripts/images/build-amd64-qcow2.sh
```

Local build outputs are ignored by git via `build/`, `dist/`, and `*.qcow2`.

## amd64 qcow2 Smoke Test

The smoke test boots a qcow2 image in snapshot mode, forwards host TCP `8443` to
the guest HTTPS port, and waits for the Open Bridge Server health endpoint over
HTTPS.

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
  OBOS_SMOKE_TIMEOUT_SECONDS=1200 \
  scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

## First Implementation Direction

Validate the `amd64-vm` qcow2 image in a VM first. The smoke test should confirm
that first boot generates appliance identity, TLS material, app secrets, and that
`obosctl status` passes through localhost and verified HTTPS proxy health.

After the amd64 VM path is repeatable, add the Raspberry Pi image builder using
the Network Installer compatible `rpi4-arm64` profile.

## Open Questions

- Should the qcow2 builder move from local script to GitHub Actions once artifact size and runner privileges are understood?
- Should Raspberry Pi images use pure Debian or Raspberry Pi OS Lite 64-bit as
  the base while keeping the userland aligned with Debian 13?
- Should development builds have an explicit opt-in SSH profile separate from release images?
- How should users recover if first boot cannot reach the network to pull the
  Open Bridge Server image?
