# Technical MVP Validation Log

This log records observed technical MVP validation milestones before a signed
release candidate exists. It complements, but does not replace,
[image-release-validation.md](image-release-validation.md).

## 2026-06-08 amd64 qcow2 Smoke Pass

Result: `PASS`

Validated commit:

```text
1b6b4671626e6ec13db06e1f273df53c5e0caa6e
```

Validation host:

```text
srv-97
```

Profile and artifact:

```text
profile=amd64-vm
artifact=dist/images/obos-amd64-vm-latest.qcow2
```

Command:

```sh
sudo OBOS_SMOKE_MEMORY=2048 \
  OBOS_SMOKE_CPUS=1 \
  OBOS_SMOKE_TIMEOUT_SECONDS=1800 \
  OBOS_SMOKE_LOG_FILE=/tmp/obos-qcow2-smoke.log \
  sh scripts/images/smoke-test-amd64-qcow2.sh dist/images/obos-amd64-vm-latest.qcow2
```

Observed smoke output:

```text
qcow2 smoke test: HTTPS proxy is reachable with status 401
qcow2 smoke test: PASS
```

Validated behavior:

- the image boots in QEMU
- first boot generates runtime identity, secrets, and TLS material
- nginx exposes the HTTPS boundary on TCP `443`
- the HTTPS web path is protected by generated Basic Auth
- open bridge server health passes through the HTTPS reverse proxy
- direct open bridge server HTTP remains closed from the VM network boundary
- Docker daemon, Docker CLI, and Compose are present enough to start the stack

Fixes confirmed by this run:

- qcow2 repository staging avoids copying the live output artifact
- provisioning runs through `sh`
- VM image DHCP networking works with the Debian generic cloud base image
- Debian Trixie `docker-cli` is installed so `/usr/bin/docker` exists

Remaining validation before technical MVP handoff:

- Raspberry Pi Network Installer image build and hardware boot
- Raspberry Pi NVMe-capable boot path validation
- runtime `security-summary` and `mvp-readiness-summary` on test appliances
- TLS trust onboarding on an administrator client
- backup, rollback staging, and restore apply plan drill
- signed release manifest and completed image validation records

