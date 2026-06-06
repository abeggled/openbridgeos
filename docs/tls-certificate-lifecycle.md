# TLS Certificate Lifecycle

open bridge operating system uses a local CA per appliance instance. This
document defines the technical MVP lifecycle policy for the local CA, the leaf
certificate used by nginx, and future imported certificates.

## Lifecycle Modes

### Leaf Renewal

Leaf renewal means creating a new `obos.local.crt` and `obos.local.key` signed
by the existing appliance local CA.

Use this mode when:

- the leaf certificate is near expiry
- the hostname changed
- IP address SANs changed and the administrator wants browser validation for
  the new address

Security impact:

- client devices do not need to import a new CA
- the local CA fingerprint stays unchanged
- the trust bundle should be exported again so support and UI surfaces show the
  new leaf fingerprint

Technical MVP status:

- planned as the first automated rotation command
- should be available through `obosctl` before it is exposed in the web UI
- must preserve the existing local CA key and certificate

### Local CA Rotation

Local CA rotation means creating a new `obos-local-ca.crt`,
`obos-local-ca.key`, and a new leaf certificate signed by that CA.

Use this mode only when:

- the CA private key is suspected to be exposed
- restoring or migrating intentionally chooses a new appliance trust identity
- the CA is near expiry and cannot safely remain trusted

Security impact:

- all client devices must trust the new CA
- the old CA should be removed from client trust stores after migration
- the old and new CA fingerprints must be shown side by side during the
  rotation window
- trust export and boot-accessible onboarding material must be regenerated

Technical MVP status:

- not an automatic default action
- must require explicit confirmation in `obosctl`
- should remain CLI-only until the web UI can display a clear re-onboarding
  warning and recovery path

### Imported Public Certificate

Imported public certificates cover administrator-provided certificate and key
material, such as a DNS-validated public certificate.

Use this mode only when:

- the administrator owns the DNS name on the certificate
- the private key can be stored with the same restrictions as local TLS keys
- renewal responsibility is explicit

Security impact:

- client devices usually do not need the appliance local CA for that hostname
- local CA trust may still be useful for future local service certificates
- incorrect imports can break the web console until console recovery is used

Technical MVP status:

- future advanced workflow
- not part of the first technical MVP test-device baseline

## Safety Rules

- `obosctl tls-generate` stays idempotent and must not rotate existing trust
  material implicitly.
- Leaf renewal must create a pre-change backup of existing leaf material.
- Local CA rotation must create a pre-change backup of the complete TLS
  directory before writing new material.
- Private keys must never be written to public trust export directories or
  boot-accessible partitions.
- Every lifecycle operation must refresh `tls-summary` and public trust export
  material after success.
- Failed lifecycle operations must leave nginx with the previous working
  certificate material.

## Validation

Before a lifecycle operation is accepted for broad release, validate:

```text
operation=leaf-renewal|local-ca-rotation|imported-public-certificate
pre_tls_summary=PASS|FAIL
pre_proxy_health=PASS|FAIL
backup_created=yes|no
operation_result=PASS|FAIL
post_tls_summary=PASS|FAIL
post_proxy_health=PASS|FAIL
trust_export_refreshed=yes|no
client_reonboarding_required=yes|no
notes=
```

For the technical MVP, only the lifecycle policy is required. Automated
certificate replacement remains a follow-up unless a release explicitly includes
the command, tests, and recovery documentation.
