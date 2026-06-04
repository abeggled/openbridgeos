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
