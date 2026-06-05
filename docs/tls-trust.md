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

- `obos.local`
- the current hostname
- `<hostname>.local`
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

Platform guidance to document before release:

- Windows: import into the local machine or current user trusted root store
- macOS: import into Keychain Access and mark as trusted for SSL
- iOS/iPadOS: install the profile, then enable full trust for the root CA
- Android: install as a user CA and document browser/app trust limitations
- Linux: install into the distribution trust store and refresh CA certificates
- Firefox: document separate Firefox trust store behavior where relevant

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

## Current Limitations

- IP SANs are generated from the current network state and are not renewed yet
  when DHCP addresses change.
- Root CA import guidance for Windows, macOS, iOS, Android, and Linux still
  needs screenshots or tested release instructions.
- Certificate replacement and rotation are not implemented yet.
- Plain HTTP redirect/onboarding behavior is still undecided; TCP `80` is closed
  for now.
