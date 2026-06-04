# 0002: Use a Local Reverse Proxy for TLS Before Public Release

## Status

Accepted. Initial nginx-based implementation exists for the development image.
Certificate replacement, HTTP redirect behavior, and web onboarding UI are still
open.

## Context

The first Open Bridge OS development path exposed Open Bridge Server directly on
TCP `8080` inside a default-drop firewall. That was useful for early local VM
validation, but plain HTTP must not become the appliance default.

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

Open Bridge OS places Open Bridge Server behind a local reverse proxy that
terminates TLS.

The initial implementation uses nginx because it is packaged in Debian, boring,
well understood, and enough for the first appliance baseline.

Default direction:

- bind Open Bridge Server to localhost only
- expose HTTPS on TCP `443`
- keep plain HTTP on TCP `80` closed for now
- use the per-appliance-instance local CA trust model from
  [0004: Use a Per-Appliance-Instance Local CA for TLS Trust Onboarding](0004-local-ca-trust-onboarding.md)
- show certificate trust material during onboarding
- document how administrators can replace the certificate with their own
- keep MQTT external exposure disabled by default, with explicit opt-in support

## Consequences

- Direct TCP `8080` exposure is no longer the default posture.
- The firewall allows TCP `443` instead of direct TCP `8080`.
- First boot generates certificate material and public trust export material.
- The security baseline audit verifies nginx, TLS material, HTTPS reachability,
  and closed external TCP `8080`.
- The obos UI and Open Bridge Server can later share one TLS entrypoint.
- MQTT remains a separate opt-in exposure decision.

## Open Questions

- Should a later image expose TCP `80` only for redirect/onboarding, or keep it
  closed entirely?
- Should certificate replacement be an `obosctl` command, a web UI workflow, or
  both?
- Should nginx remain the long-term proxy, or should obos eventually own this in
  the agent/web service?
