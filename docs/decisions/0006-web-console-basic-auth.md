# 0006: Protect the Appliance Web Console with Per-Instance Basic Auth

## Status

Accepted for technical MVP test devices.

## Context

The obos web console and `/obos/api/` bridge are served through nginx on the
same HTTPS origin as open bridge server. The bridge can trigger confirmed
mutations such as service lifecycle changes, updates, backups, restore staging,
TLS export, MQTT LAN exposure, hostname changes, and timezone changes.

For test devices, exposing these paths without an appliance-level access check
would make the HTTPS boundary too broad even when individual mutations still
require confirmation tokens.

## Decision

open bridge operating system protects both `/obos/` and `/obos/api/` with nginx
Basic Auth by default.

First boot does not generate a reusable administrator password. Instead it
creates a local onboarding marker and exposes only these unauthenticated paths:

- `/obos/onboarding/`
- `/obos/api/v1/onboarding/`

The administrator sets the first web console password during this onboarding
flow. After setup, the onboarding marker is removed and nginx Basic Auth protects
the normal console and agent API.

Per-appliance-instance credentials use:

- username defaults to `admin`
- password is set by the administrator during first web onboarding
- nginx password hash is stored in `/etc/obos/web.htpasswd`
- the credential record is stored in `/etc/obos/web-admin.env`

The password file is readable by nginx and not world-readable. The credential
record is root-only and treated as sensitive.

For headless onboarding, first boot may write `OBOS-ONBOARDING.txt` to a
writable boot-accessible partition. That file points to the onboarding URL and
must not contain a password.

## Consequences

- The web console and local agent API have a real access gate for test devices.
- Basic Auth is not the final long-term user/session model, but it is simple,
  auditable, and supported by stock Debian nginx.
- Password rotation is an explicit confirmed workflow through `obosctl` and
  `obos-agent`; the web UI can add a polished display later.
- The unauthenticated onboarding endpoint is only available before credentials
  exist. Test appliances should be attached to a trusted setup network until
  onboarding is complete.
