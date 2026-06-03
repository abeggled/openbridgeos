# 0002: Use a Local Reverse Proxy for TLS Before Public Release

## Status

Accepted as release direction. Not yet implemented for the first development
image.

## Context

The first Open Bridge OS development path exposes Open Bridge Server directly on
TCP `8080` inside a default-drop firewall. This is acceptable for early local VM
validation, but plain HTTP must not become the long-term appliance default.

Open Bridge OS needs a TLS story that works for:

- LAN-only appliances without public DNS
- Raspberry Pi and x86_64 images
- users who cannot manage certificates manually
- future obos administration UI
- Open Bridge Server behind the same appliance boundary

Public ACME certificates are not always available for LAN installations. A
self-signed certificate is easy to generate, but it creates a trust/onboarding
problem for browsers and users.

## Decision

Before a public release, Open Bridge OS should place Open Bridge Server behind a
local reverse proxy that terminates TLS.

The initial release direction is:

- bind Open Bridge Server to localhost only
- expose HTTPS on TCP `443`
- redirect or close plain HTTP on TCP `80`
- generate a per-device local certificate during first boot or onboarding
- show the certificate fingerprint during onboarding
- document how administrators can replace the certificate with their own
- keep MQTT external exposure disabled by default, with explicit opt-in support

The reverse proxy implementation should be decided after the first Debian VM
baseline has passed. Caddy, nginx, and a small purpose-built proxy are candidate
paths.

## Consequences

- The current TCP `8080` exposure is explicitly a development baseline, not a
  release posture.
- The firewall must eventually allow TCP `443` instead of direct TCP `8080`.
- The security baseline audit must grow TLS checks before public images.
- First boot needs certificate material generation and secure storage.
- The obos UI and Open Bridge Server can later share one TLS entrypoint.
- MQTT remains a separate opt-in exposure decision.

## Open Questions

- Should the first public image expose TCP `80` only for redirect/onboarding,
  or keep it closed entirely?
- Should obos generate a local CA or only a leaf certificate?
- How should users verify and trust the certificate on phones/tablets?
- Should certificate replacement be an `obosctl` command, a web UI workflow, or
  both?
