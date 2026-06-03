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
- First boot performs per-device initialization.
- Build output includes checksums.
- Release artifacts should be signed before public distribution.
- The same provisioning scripts should be used for manual installs and images.

## First Implementation Direction

Start with a Debian 13 `amd64` raw or qcow2 development image. Once that boots
and starts Open Bridge Server reliably, add the Raspberry Pi image path.

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
