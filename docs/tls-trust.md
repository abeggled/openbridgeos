# TLS Trust Material

Open Bridge OS will use a local CA per appliance instance before public release.
The current scripts make the trust model testable without enabling the reverse
proxy yet.

## Generate TLS Material

On a provisioned appliance instance:

```sh
sudo /usr/lib/obos/generate-tls-material.sh
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
sudo /usr/lib/obos/print-trust-info.sh
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

## Client Trust

Administrators may install `/etc/obos/tls/obos-local-ca.crt` on client devices
to remove browser warnings for certificates issued by this appliance instance.

Important:

- the local CA is unique to one appliance instance
- do not reuse it on another appliance instance
- treat backups containing `/etc/obos/tls` as sensitive
- replacing or rotating the CA requires clients to trust the new CA

## Current Limitations

- The reverse proxy is not implemented yet.
- TLS material is not generated automatically during provisioning.
- IP SANs are generated from the current network state and are not renewed yet
  when DHCP addresses change.
- Root CA import guidance for Windows, macOS, iOS, Android, and Linux is still
  needed.
