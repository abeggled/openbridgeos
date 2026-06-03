# 0004: Use a Per-Appliance-Instance Local CA for TLS Trust Onboarding

## Status

Accepted as release direction. Not yet implemented.

## Context

Open Bridge OS needs HTTPS by default before public release, but many target
installations are LAN-only and have no public DNS name. Public ACME certificates
are therefore not a universal default.

A single self-signed leaf certificate is easy to generate, but it creates a poor
user experience and cannot easily cover future services or certificate renewal.
A public certificate path is valuable, but it must remain optional because it
requires DNS/domain ownership or an internet-reachable challenge path.

Each obos installation, whether running on a Raspberry Pi, mini PC, server, or
VM, is an appliance instance. The appliance also needs a way for users to
distinguish their real local appliance instance from a LAN attacker during first
contact.

## Decision

Open Bridge OS should generate a local certificate authority per appliance
instance during first boot or first onboarding, then use it to issue local
service certificates.

Default release direction:

- generate a unique local CA for each appliance instance
- store CA private key material under `/etc/obos/tls` with restrictive
  permissions
- issue a leaf certificate for the active appliance hostname and local names
- include SANs for `obos.local`, `<hostname>.local`, and current local IP
  addresses where practical
- terminate HTTPS at the obos reverse proxy
- bind Open Bridge Server to localhost behind that proxy
- expose HTTPS on TCP `443`
- keep TCP `8080` closed externally before public release

## Trust Onboarding

Trust must be explicit. The user must not be asked to blindly trust a random
browser warning.

The first onboarding flow should provide at least two independent verification
paths:

1. Local console or attached display shows the CA fingerprint and onboarding URL.
2. `/usr/lib/obos/print-trust-info.sh` prints the CA fingerprint, leaf
   fingerprint, hostname, IP addresses, and root CA export path.
3. The obos web onboarding page shows the same fingerprint, but the web page
   alone is not sufficient proof because it can be spoofed before trust is
   established.

For Raspberry Pi and headless systems, the image process should explore writing
a first-boot trust summary to a boot-accessible partition after certificate
generation. This is useful but not required for the first Debian VM baseline.

## Root CA Installation

Administrators may install the appliance instance's root CA into their client
devices if they want warning-free browser access.

The UI and documentation must be clear that:

- the root CA is unique to one appliance instance
- it should not be reused across installations
- exporting it is sensitive
- installing it makes the client trust certificates issued by that appliance
  instance's CA
- replacing or rotating it will require clients to trust the new CA

## Public CA Option

Administrators who own a DNS name may replace the local certificate path with a
publicly trusted certificate later.

This should be supported as an advanced path, not as the default requirement.
Possible later modes:

- imported certificate and key
- ACME DNS-01 for private/LAN appliances
- ACME HTTP-01 only when the appliance is intentionally internet reachable

## Consequences

- First boot needs TLS material generation before public release.
- Backup and restore must treat `/etc/obos/tls` as secret material.
- The security baseline audit must verify certificate presence, permissions,
  HTTPS availability, and closed external TCP `8080` before public release.
- The onboarding UI must display trust material clearly and without implying
  that a browser warning alone is safe.
- Support docs must include platform-specific root CA import guidance for
  Windows, macOS, iOS, Android, and Linux.

## Rejected Alternatives

### Plain self-signed leaf only

Simple, but poor renewal and multi-service story. It also does not create a
clean path for trusting several local service certificates.

### Public ACME certificate as the only supported default

Not viable for LAN-only and offline-ish deployments. It would force users into
DNS/domain operations before the appliance is useful.

### Shared Open Bridge OS root CA

Rejected. A shared root CA would be a high-impact compromise target and would
violate the per-appliance-instance trust model.

## Open Questions

- Should the local CA be generated automatically on first boot or during an
  authenticated first-run onboarding step?
- How should IP address SANs be renewed when DHCP leases change?
- Should obos generate a QR code for the fingerprint and root CA download URL?
- Should certificate rotation be available in `obosctl`, web UI, or both?
