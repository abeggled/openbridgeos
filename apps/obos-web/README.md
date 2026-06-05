# obos web

`obos-web` is the future appliance console for open bridge operating system.

The first implementation is intentionally static. It defines the operational
screen structure and the data-contract placeholders that will later be filled by
the local `obos-agent`. It must not write appliance files directly and must not
call arbitrary shell commands.

`app.js` reads the first read-only HTTP bridge endpoints below `/obos/api/`,
fills matching `data-agent-field` placeholders, and can run the confirmed backup
mutation. It keeps restore apply and other mutating workflows unavailable until
their confirmation flows are implemented.

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
- agent mutation audit
- logs metadata

The TLS trust panel surfaces certificate presence, SHA-256 fingerprints, expiry
warning state, and trust bundle availability for onboarding and support.

The security panel can refresh the non-destructive security baseline audit
through the read-only local agent endpoint. It can also run the confirmed web
console password rotation and shows the newly generated password from the
response for the administrator who triggered the operation.

The logs panel starts with metadata only. Raw log viewing remains disabled
because service logs can contain sensitive operational data.

Start, stop, restart, update, backup creation, and restore staging are the first
confirmed mutations exposed through the HTTP bridge. They use the same
`obos-agent <action> --confirm <action>` contract and audit rules. Restore
staging uses the latest backup path from `backup-summary` and remains
non-destructive.
Raw backup archive download remains disabled because appliance backups contain
secret-bearing configuration. Download and migration support uses the encrypted
portable backup format `obos-portable-backup-v1`. The web UI can create and
download encrypted portable exports from the latest listed backup, upload
encrypted portable backups, and decrypt them into private import staging.
Restore apply remains outside the HTML controls.

Restore apply and other mutation controls are intentionally disabled in HTML.
