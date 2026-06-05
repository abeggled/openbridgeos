# obos web

`obos-web` is the future appliance console for open bridge operating system.

The first implementation is intentionally static. It defines the operational
screen structure and the data-contract placeholders that will later be filled by
the local `obos-agent`. It must not write appliance files directly and must not
call arbitrary shell commands.

`app.js` reads the first read-only HTTP bridge endpoints below `/obos/api/` and
fills matching `data-agent-field` placeholders. It keeps restore apply and all
mutating workflows unavailable until the confirmation flow is implemented.

The future HTTP bridge should live below `/obos/api/` on the same HTTPS origin,
bind only locally or to a Unix socket, and call `obos-agent` rather than
`obosctl` or a shell directly. Confirmed mutations stay unavailable over HTTP
until the read-only bridge and service hardening are validated.

## Contract

The UI is expected to consume the allowlisted commands documented in
`docs/web-ui-agent-contract.md`.

Initial read-only panels:

- appliance status
- update state
- backup state
- restore staging state
- MQTT exposure
- TLS trust
- security baseline
- agent mutation audit

The TLS trust panel surfaces certificate presence, SHA-256 fingerprints, expiry
warning state, and trust bundle availability for onboarding and support.

Confirmed mutations will be wired only after an HTTP boundary for `obos-agent`
exists and keeps the same confirmation and audit rules.

Current mutation controls are intentionally disabled in HTML. The first HTTP
bridge only exposes read-only endpoints.
