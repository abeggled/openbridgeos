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
- MQTT LAN exposure must remain opt-in and visible whenever it is enabled.
- Restore apply must not be implemented in the UI until the CLI has an explicit
  apply command with confirmation gates.

## Read-Only Commands

| UI area | Command | Format |
| --- | --- | --- |
| Appliance status | `obosctl status-summary` | `obos-status-summary-v1` |
| Last update | `obosctl update-summary` | `obos-update-summary-v1` |
| Last update rollback plan | `sudo obosctl update-rollback-plan` | `obos-update-rollback-plan-v1` |
| Backup inventory | `obosctl backup-list` | `obos-backup-list-v1` |
| MQTT exposure | `sudo obosctl mqtt-summary` | `obos-mqtt-summary-v1` |
| TLS trust | `obosctl tls-summary` | `obos-tls-summary-v1` |
| Security baseline | `sudo obosctl security-summary` | `obos-security-baseline-summary-v1` |

These commands print key-value records. The agent should reject unknown format
versions instead of guessing.

## Mutating Commands

| UI action | Command |
| --- | --- |
| Start open bridge server | `sudo obosctl start` |
| Stop open bridge server | `sudo obosctl stop` |
| Restart open bridge server | `sudo obosctl restart` |
| Update appliance app stack | `sudo obosctl update` |
| Create backup | `sudo obosctl backup` |
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
obos-agent update-summary
obos-agent update-rollback-plan
obos-agent backup-list
obos-agent mqtt-summary
obos-agent tls-summary
obos-agent security-summary
```

The response envelope uses format `obos-agent-response-v1` and includes the
requested action, exit code, timeout marker, stdout block, and stderr block.
The action inventory uses format `obos-agent-actions-v1` and marks every current
action as `mutating=false` or `mutating=true`. Mutating entries include the
required confirmation token. Mutating responses are paired with metadata-only
audit log entries.
