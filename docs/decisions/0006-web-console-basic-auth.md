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

First boot generates per-appliance-instance credentials:

- username defaults to `admin`
- password is randomly generated
- nginx password hash is stored in `/etc/obos/web.htpasswd`
- the initial credential record is stored in `/etc/obos/web-admin.env`

The password file is readable by nginx and not world-readable. The credential
record is root-only and treated as sensitive.

For headless onboarding, first boot may write `OBOS-ONBOARDING.txt` to a
writable boot-accessible partition. That file contains the initial web console
password and must be removed after onboarding.

## Consequences

- The web console and local agent API have a real access gate for test devices.
- Basic Auth is not the final long-term user/session model, but it is simple,
  auditable, and supported by stock Debian nginx.
- Password rotation should become an explicit `obosctl` and web UI workflow
  before public release.
- The boot-accessible onboarding file is sensitive. It is acceptable for the
  technical MVP only because it solves headless first access without requiring
  SSH, but it must be clearly documented.
