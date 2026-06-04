# 0001: Target Debian 13 Trixie for the First Appliance Image

## Status

Accepted for the first development image.

## Context

open bridge operating system should use a conservative Debian base and avoid third-party
package repositories where possible. The open bridge server app stack is managed
with `docker compose`, so the base operating system needs Docker and Compose v2
available in a maintainable way.

Debian 12 Bookworm ships the legacy `docker-compose` 1.x package. Debian 13
Trixie ships `docker-compose` 2.x and documents the `docker compose up` command
for running Compose files.

## Decision

The first obos development image targets Debian 13 Trixie on `amd64` and
`arm64`.

Use Debian packages first:

- `docker.io`
- `docker-compose`
- `openssl`
- `ca-certificates`

Do not add Docker's upstream APT repository in the default image until there is
a clear reason to trade Debian's packaging and security update flow for newer
Docker releases.

## Consequences

- The first image can use Compose v2 without a third-party repository.
- Package provenance is simpler for a security-focused appliance.
- Raspberry Pi support should use a Debian 13 compatible 64-bit base.
- Debian 12 can be revisited only if we add a separate Compose v2 installation
  path.
