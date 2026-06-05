# 0005 Encrypted Portable Backups

## Status

Accepted.

## Context

Appliance backups contain secret-bearing configuration:

- open bridge server JWT secret
- internal MQTT service password
- TLS private key material
- appliance identifier
- application and service state

Raw backup archives are therefore safe only as local root-owned files. At the
same time, users need a practical way to download a backup and import it on a
different open bridge operating system appliance for migration, hardware
replacement, and disaster recovery.

## Decision

The web UI must not download raw appliance backup archives.

Downloadable backups must be a separate encrypted portable export format. The
initial target format is:

```text
obos-portable-backup-v1
```

The portable export workflow will wrap a validated local appliance backup in an
authenticated encryption envelope before it becomes downloadable. The export
must record non-secret metadata next to the encrypted payload:

- export format version
- source appliance identifier hash, not the raw identifier
- creation time
- backup manifest hash
- encryption method
- key derivation parameters or recipient key identifier
- payload SHA-256

The encrypted payload must use modern authenticated encryption. The default
direction is passphrase-based encryption with memory-hard key derivation for
human migrations. A later recipient-key mode may be added for managed fleet
operations.

The import workflow must never apply a portable backup directly to the live
system. It must:

1. upload the encrypted portable backup to private import staging
2. decrypt only after explicit user confirmation and passphrase entry
3. verify the portable metadata and payload hash
4. run the existing backup inspection checks
5. extract into private restore staging
6. show an import and restore apply plan
7. require a fresh pre-restore backup before any future live apply step

## Consequences

- Backup download becomes possible without exposing raw secrets in transit or in
  the browser download folder.
- Migration between appliances becomes a first-class workflow instead of an
  accidental side effect of raw file access.
- Import can reuse the existing restore staging safety model.
- The web UI needs separate controls for local backup creation, encrypted export
  creation, encrypted export download, encrypted import upload, and restore
  staging.
- Recovery UX must clearly explain that losing the export passphrase makes the
  portable backup unrecoverable.

## Non-Goals

- No raw backup archive downloads from the web UI.
- No live restore apply from uploaded content.
- No automatic trust carry-over unless the import plan explicitly shows that TLS
  identity material will be restored.
