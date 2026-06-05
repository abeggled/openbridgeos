# Web UI Agent Contract

The future open bridge operating system web UI should use a small local agent
instead of parsing human-oriented command output or writing appliance files
directly.

## Principles

- The web UI should call stable `obosctl` commands through a privileged local
  agent.
- Read-only views should prefer `*-summary` and `*-list` commands.
- Mutating actions must stay explicit, auditable, and mapped to existing
  `obosctl` commands.
- The UI must treat backups, app environment files, TLS private keys, and
  restore staging directories as sensitive.
- Raw service logs are sensitive by default; read-only log views should start
  with metadata-only availability summaries.
- MQTT LAN exposure must remain opt-in and visible whenever it is enabled.
- Restore apply must not be implemented in the UI until the CLI has an explicit
  apply command with confirmation gates.

## Read-Only Commands

| UI area | Command | Format |
| --- | --- | --- |
| Appliance status | `obosctl status-summary` | `obos-status-summary-v1` |
| Host basics | `obosctl system-summary` | `obos-system-summary-v1` |
| Last update | `obosctl update-summary` | `obos-update-summary-v1` |
| Last update rollback plan | `sudo obosctl update-rollback-plan` | `obos-update-rollback-plan-v1` |
| Latest backup | `obosctl backup-summary` | `obos-backup-summary-v1` |
| Backup inventory | `obosctl backup-list` | `obos-backup-list-v1` |
| Backup retention plan | `obosctl backup-prune-plan` | `obos-backup-prune-plan-v1` |
| Logs metadata | `sudo obosctl logs-summary` | `obos-logs-summary-v1` |
| Restore staging inventory | `sudo obosctl restore-stage-summary` | `obos-restore-stage-summary-v1` |
| MQTT exposure | `sudo obosctl mqtt-summary` | `obos-mqtt-summary-v1` |
| TLS trust | `obosctl tls-summary` | `obos-tls-summary-v1` |
| Security baseline | `sudo obosctl security-summary` | `obos-security-baseline-summary-v1` |
| Agent mutation audit | `sudo obosctl agent-audit-summary` | `obos-agent-audit-summary-v1` |

These commands print key-value records. The agent should reject unknown format
versions instead of guessing.

`obos-backup-summary-v1` includes latest-backup inspection status and whether the
latest backup manifest records secrets, logs, and TLS private key material.

`obos-logs-summary-v1` is metadata-only. It reports log tooling availability and
recent journal volume, but it deliberately does not return raw log lines.

## Mutating Commands

| UI action | Command |
| --- | --- |
| Start open bridge server | `sudo obosctl start` |
| Stop open bridge server | `sudo obosctl stop` |
| Restart open bridge server | `sudo obosctl restart` |
| Update appliance app stack | `sudo obosctl update` |
| Create backup | `sudo obosctl backup` |
| Prune old backups | `sudo obosctl backup-prune --confirm backup-prune` |
| Generate TLS material | `sudo obosctl tls-generate` |
| Export TLS trust bundle | `sudo obosctl tls-export` |
| Enable MQTT LAN access | `sudo obosctl mqtt-enable-lan [source-cidr]` |
| Disable MQTT LAN access | `sudo obosctl mqtt-disable-lan` |

Mutating commands should be shown with clear confirmation prompts in the UI.
MQTT enablement should show whether the firewall source scope is unrestricted or
CIDR-limited after the operation.

The local agent exposes these mutations only with explicit confirmation:

```sh
obos-agent start --confirm start
obos-agent stop --confirm stop
obos-agent restart --confirm restart
obos-agent update --confirm update
obos-agent backup --confirm backup
obos-agent backup-prune --confirm backup-prune
obos-agent restore-stage <backup.tar.gz> --confirm restore-stage
obos-agent tls-generate --confirm tls-generate
obos-agent tls-export --confirm tls-export
obos-agent mqtt-enable-lan [source-cidr] --confirm mqtt-enable-lan
obos-agent mqtt-disable-lan --confirm mqtt-disable-lan
```

Confirmed mutating actions append metadata-only audit entries using format
`obos-agent-audit-v1`. Audit entries record the timestamp, action, exit code,
and timeout state; command stdout, stderr, secrets, and file contents are not
written to the audit log. The provisioned audit log is rotated by logrotate and
new log files are created as `0640 obos-agent:obos-agent`.
Restore staging accepts only appliance backup archives below the configured
backup directory before crossing the sudo boundary.
Restore stage inspection accepts only private restore staging directories below
the configured restore staging directory.
Restore apply planning uses the same stage path validation and remains
non-destructive.

## Restore Workflow

The UI may expose the current non-destructive restore workflow:

1. `obosctl restore-inspect <backup.tar.gz>`
2. `obosctl restore-plan <backup.tar.gz>`
3. `sudo obosctl restore-stage <backup.tar.gz>`
4. `sudo obosctl restore-stage-inspect <stage-dir>`
5. `sudo obosctl restore-apply-plan <stage-dir>`

The UI must not replace live appliance files. A future apply workflow needs a
separate CLI command, explicit confirmation, a fresh pre-restore backup, service
stop/start ordering, permission normalization, health checks, and a security
baseline audit.

## Agent Notes

The local agent should run with the minimum privilege needed to call `obosctl`
and should not expose a raw shell. It should allowlist commands and arguments,
enforce timeouts, capture exit status, and return the command format version
along with stdout and stderr.

The provisioned privilege boundary uses the `obos-agent` system user and
`/etc/sudoers.d/obos-agent`. The sudoers policy permits only the documented
`/usr/bin/obosctl` actions with non-interactive `sudo -n`; it does not grant a
general root shell. Optional MQTT source CIDR input is validated by the agent
before crossing the sudo boundary.

The initial agent skeleton is installed as `obos-agent`. It exposes a stable
action inventory and read-only status actions:

```sh
obos-agent actions
obos-agent status-summary
obos-agent system-summary
obos-agent update-summary
obos-agent update-rollback-plan
obos-agent backup-summary
obos-agent backup-list
obos-agent backup-prune-plan
obos-agent logs-summary
obos-agent restore-stage-summary
obos-agent restore-stage-inspect <stage-dir>
obos-agent restore-apply-plan <stage-dir>
obos-agent mqtt-summary
obos-agent tls-summary
obos-agent security-summary
obos-agent agent-audit-summary
```

The response envelope uses format `obos-agent-response-v1` and includes the
requested action, exit code, timeout marker, stdout block, and stderr block.
The action inventory uses format `obos-agent-actions-v1` and marks every current
action as `mutating=false` or `mutating=true`. Mutating entries include the
required confirmation token. Mutating responses are paired with metadata-only
audit log entries.

## HTTP Bridge Boundary

The web UI should not execute `obos-agent` directly in the browser. A future
HTTP bridge may sit between nginx and `obos-agent`, but it must stay a local
appliance boundary:

- Bind only to `127.0.0.1` or to a Unix domain socket.
- Be reachable through nginx only below `/obos/api/` on the existing HTTPS
  origin.
- Disable cross-origin browser access; no CORS wildcard is allowed.
- Serve read-only actions as explicit `GET /obos/api/v1/actions/<action>`
  endpoints that map one-to-one to documented non-mutating `obos-agent`
  actions.
- Serve mutations as `POST /obos/api/v1/actions/<action>` endpoints with a JSON
  body containing the same confirmation token required by `obos-agent`.
- Reject unknown actions, unknown arguments, missing confirmation tokens, and
  unexpected request body fields.
- Return the existing `obos-agent-response-v1` envelope, or a documented
  `obos-agent-http-error-v1` error envelope for HTTP-layer validation failures.
- Never return backup archive contents, app environment files, TLS private keys,
  restore staged file contents, or raw command stderr without the existing agent
  envelope.
- Run under a dedicated unprivileged service account and call only the installed
  `obos-agent` binary, never `obosctl` or a shell directly.
- Use systemd hardening around the local sudo boundary: `PrivateTmp=true`,
  `ProtectSystem=strict`, `ProtectHome=true`, `LockPersonality=true`,
  `MemoryDenyWriteExecute=true`, `RestrictRealtime=true`, and
  `SystemCallArchitectures=native`.
- Do not enable `NoNewPrivileges=true` while the bridge depends on
  `obos-agent` using `sudo -n`; that would block the intended sudoers
  allowlist boundary. `NoNewPrivileges=true` becomes mandatory only after the
  HTTP bridge no longer needs sudo privilege elevation.
- Use a narrow `ReadWritePaths=` entry only for agent state if the bridge itself
  needs state.

The first implementation should start with read-only endpoints for `actions`,
`status-summary`, `system-summary`, `update-summary`, `update-rollback-plan`,
`backup-summary`, `backup-list`, `backup-prune-plan`, `logs-summary`,
`restore-stage-summary`, `mqtt-summary`, `tls-summary`, `security-summary`, and
`agent-audit-summary`.

The first confirmed HTTP mutation is `POST /obos/api/v1/actions/backup`. It
requires `Content-Type: application/json` and exactly this body:

```json
{"confirm":"backup"}
```

The bridge forwards it to `obos-agent backup --confirm backup`, keeps the
existing agent audit trail, and returns the normal `obos-agent-response-v1`
envelope. Backup archive download remains out of scope because appliance
backups contain secrets.

The initial bridge is installed as `obos-agent-http.service`. It binds to
`127.0.0.1:8091`, is proxied by nginx below `/obos/api/`, exposes the first
read-only endpoint set, and allows only the confirmed backup mutation. Other
POST requests return `obos-agent-http-error-v1` with `mutations-disabled` or
`unknown-action`.
