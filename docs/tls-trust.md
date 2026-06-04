# TLS Trust Material

Open Bridge OS will use a local CA per appliance instance before public release.
The current scripts make the trust model testable without enabling the reverse
proxy yet.

## Generate TLS Material

On a provisioned appliance instance:

```sh
sudo obosctl tls-generate
```

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

The bundle intentionally excludes private keys. It is suitable as a source for a
future onboarding UI, boot-accessible trust summary, or manual support workflow.
The CA certificate can be copied to client devices after the fingerprint has
been verified through an out-of-band path.

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

- The reverse proxy is not implemented yet.
- TLS material is not generated automatically during provisioning.
- IP SANs are generated from the current network state and are not renewed yet
  when DHCP addresses change.
- Root CA import guidance for Windows, macOS, iOS, Android, and Linux still
  needs screenshots or tested release instructions.
