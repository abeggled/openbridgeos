# TLS Trust Material

open bridge operating system uses a local CA per appliance instance for the default HTTPS
reverse proxy. The current implementation makes open bridge server reachable via
nginx on TCP `443`, while open bridge server itself binds to localhost.

## Generate TLS Material

First boot generates TLS material automatically. To regenerate or create it
manually on a provisioned appliance instance:

```sh
sudo obosctl tls-generate
```

TLS generation is idempotent. If the local CA and leaf certificate material
already exist, `obosctl tls-generate` preserves them instead of rotating the
appliance TLS identity implicitly.

This creates:

```text
/etc/obos/tls/obos-local-ca.key
/etc/obos/tls/obos-local-ca.crt
/etc/obos/tls/obos.local.key
/etc/obos/tls/obos.local.crt
/etc/obos/tls/obos.local.ext
```

Permissions:

```text
/etc/obos/tls/                 0700
/etc/obos/tls/*.key            0600
/etc/obos/tls/*.crt            0644
```

The leaf certificate includes SANs for:

- `obs.local`
- current local IP addresses where detectable

## Print Trust Information

```sh
sudo obosctl tls-info
```

The output includes:

- appliance hostname
- appliance IP addresses
- local CA certificate path
- leaf certificate path
- local CA SHA-256 fingerprint
- leaf certificate SHA-256 fingerprint

Use this output as an out-of-band verification source. A web page alone is not
sufficient proof before the client trusts the appliance instance.

## Check TLS Status

```sh
obosctl tls-status
```

The status command verifies that the local CA and leaf certificates are present,
parseable, currently valid, and not close to expiry. By default, certificates
that expire within 30 days produce a warning. Override the warning window for
tests or support checks with:

```sh
OBOS_TLS_EXPIRY_WARN_DAYS=90 obosctl tls-status
```

## Plan Leaf Renewal

```sh
obosctl tls-renew-leaf-plan
```

The plan command is non-destructive. It verifies that the local CA certificate,
local CA key, leaf certificate, and leaf key are present and parseable. It then
prints `obos-tls-leaf-renewal-plan-v1`, including the current CA and leaf
fingerprints, whether renewal is due within the configured warning window, and
the required post-change gates for the confirmed CLI renewal command.

Leaf renewal preserves the appliance local CA and therefore does not require
client devices to trust a new CA. It still requires a fresh trust export so UI
and support surfaces can show the new leaf fingerprint after renewal.

## Renew Leaf Certificate

```sh
sudo obosctl tls-renew-leaf --confirm tls-renew-leaf
```

The renewal command is CLI-only for the technical MVP. It creates a private
backup of the current leaf key, leaf certificate, and leaf extension file below
`/etc/obos/tls/backups`, generates a new leaf key and certificate signed by the
existing appliance local CA, verifies the new certificate against that CA,
refreshes the public trust export, and reloads nginx when it is active.

The command preserves the local CA fingerprint. Client devices do not need to
trust a new CA after leaf-only renewal, but administrators should refresh any
displayed trust bundle so the new leaf fingerprint is visible.

## Export Trust Bundle

```sh
sudo obosctl tls-export
```

This writes public trust artifacts to:

```text
/srv/obos/state/trust/obos-local-ca.crt
/srv/obos/state/trust/obos.local.crt
/srv/obos/state/trust/trust-info.txt
```

The bundle intentionally excludes private keys. It is suitable as a source for
the web UI, boot-accessible trust summary, or manual support workflow.
The CA certificate can be copied to client devices after the fingerprint has
been verified through an out-of-band path.

## Boot-Accessible Trust Summary

First boot also tries to write public trust material to a mounted boot partition
for headless Raspberry Pi onboarding:

```sh
sudo obosctl tls-export-boot
```

The helper looks for a writable mounted boot directory in this order:

- `/boot/firmware`
- `/boot/efi`
- `/boot`

If one is found, it writes:

```text
OBOS-TRUST.txt
OBOS-LOCAL-CA.crt
```

The boot summary contains the same fingerprints as `obosctl tls-info` plus the
public local CA certificate. It does not export private keys. If no writable
boot partition is mounted, the helper exits successfully and leaves the normal
trust bundle below `/srv/obos/state/trust` unchanged.

For image tests or custom mount layouts, override the target directory with:

```sh
sudo OBOS_BOOT_TRUST_DIR=/mnt/obos-boot obosctl tls-export-boot
```

## Client Trust

Administrators may install `/etc/obos/tls/obos-local-ca.crt` or the exported
`/srv/obos/state/trust/obos-local-ca.crt` on client devices to remove browser
warnings for certificates issued by this appliance instance.

See [client-ca-trust.md](client-ca-trust.md) for the technical MVP client trust
checklist and release validation matrix.

Important:

- verify the CA fingerprint before importing it
- the local CA is unique to one appliance instance
- do not reuse it on another appliance instance
- treat backups containing `/etc/obos/tls` as sensitive
- replacing or rotating the CA requires clients to trust the new CA
- installing this CA makes the client trust certificates issued by this appliance
  instance's CA

The underlying helper scripts are installed below `/usr/lib/obos` for packaging
and automation, but administrators should use `obosctl` as the stable interface.

## Certificate Lifecycle

Certificate lifecycle rules are defined in
[tls-certificate-lifecycle.md](tls-certificate-lifecycle.md).

Summary:

- `obosctl tls-generate` is idempotent and does not rotate existing trust
  material implicitly.
- `obosctl tls-renew-leaf-plan` is non-destructive and preserves the local CA.
- `sudo obosctl tls-renew-leaf --confirm tls-renew-leaf` renews the leaf
  certificate only and remains CLI-only for the technical MVP.
- Leaf renewal keeps the existing appliance local CA and should not require
  client devices to trust a new CA.
- Local CA rotation creates a new trust identity and requires explicit client
  re-onboarding.
- Imported public certificates are a future advanced workflow, not a technical
  MVP baseline requirement.

## Current Limitations

- IP SANs are generated from the current network state and are not renewed yet
  when DHCP addresses change.
- Client CA import guidance still needs screenshots and tested release
  instructions for each supported platform.
- Leaf certificate renewal is implemented as a CLI-only command. Local CA
  rotation and imported public certificates are not implemented yet.
- Plain HTTP redirect/onboarding behavior is still undecided; TCP `80` is closed
  for now.
