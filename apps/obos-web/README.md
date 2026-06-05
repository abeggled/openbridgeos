# obos web

`obos-web` is the appliance console for open bridge operating system.

The implementation is intentionally static. It defines the operational screen
structure, reads allowlisted local agent endpoints, and sends only confirmed
mutation requests through the HTTP bridge. It must not write appliance files
directly and must not call arbitrary shell commands.

`app.js` reads the HTTP bridge endpoints below `/obos/api/`, fills matching
`data-agent-field` placeholders, and runs selected confirmed mutations. Restore
apply remains unavailable in the browser.

The HTTP bridge lives below `/obos/api/` on the same HTTPS origin, binds only
locally, and calls `obos-agent` rather than `obosctl` or a shell directly.

## Contract

The UI is expected to consume the allowlisted commands documented in
`docs/web-ui-agent-contract.md`.

Initial read-only panels:

- appliance status
- host basics
- update state
- backup state
- restore staging state
- MQTT exposure
- TLS trust
- security baseline
- technical MVP readiness
- agent mutation audit
- logs metadata

The TLS trust panel surfaces certificate presence, SHA-256 fingerprints, expiry
warning state, and trust bundle availability for onboarding and support.

The security panel can refresh the non-destructive security baseline audit
and technical MVP runtime readiness through read-only local agent endpoints. It
can also run the confirmed web console password rotation and shows the newly
generated password from the response for the administrator who triggered the
operation.

The logs panel starts with metadata only. Raw log viewing remains disabled
because service logs can contain sensitive operational data.

Start, stop, restart, update, backup creation, restore staging, hostname and
timezone changes, MQTT LAN opt-in/opt-out, TLS generation/export, encrypted
portable backup export/import staging, and web console password rotation are
confirmed mutations exposed through the HTTP bridge. They use the same
`obos-agent <action> --confirm <action>` contract and audit rules.
Raw backup archive download remains disabled because appliance backups contain
secret-bearing configuration. Download and migration support uses the encrypted
portable backup format `obos-portable-backup-v1`. The web UI can create and
download encrypted portable exports from the latest listed backup, upload
encrypted portable backups, and decrypt them into private import staging.
Restore apply remains outside the HTML controls.

Restore apply controls are intentionally absent from HTML.
