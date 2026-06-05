# obos web

`obos-web` is the future appliance console for open bridge operating system.

The first implementation is intentionally static. It defines the operational
screen structure and the data-contract placeholders that will later be filled by
the local `obos-agent`. It must not write appliance files directly and must not
call arbitrary shell commands.

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

Confirmed mutations will be wired only after an HTTP boundary for `obos-agent`
exists and keeps the same confirmation and audit rules.
