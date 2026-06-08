# Client CA Trust Guide

open bridge operating system uses one local CA per appliance instance. Client
devices may trust this CA so browsers can validate the appliance HTTPS
certificate for `obs.local` and the appliance IP addresses.

This guide is a technical MVP checklist. Platform-specific steps still need
release validation and screenshots before broad user-facing publication.

## Trust Inputs

Use one of these public CA certificate sources:

- `/etc/obos/tls/obos-local-ca.crt` on the appliance
- `/srv/obos/state/trust/obos-local-ca.crt` after `sudo obosctl tls-export`
- `OBOS-LOCAL-CA.crt` on the boot-accessible partition after
  `sudo obosctl tls-export-boot`

Use one of these fingerprint sources:

- `sudo obosctl tls-info`
- `obosctl tls-summary`
- `/srv/obos/state/trust/trust-info.txt`
- `OBOS-TRUST.txt` on the boot-accessible partition

## Safety Rules

- Verify the local CA SHA-256 fingerprint before importing the CA.
- Trust only the CA for the appliance instance you are onboarding.
- Do not copy the CA private key to client devices.
- `OBOS-ONBOARDING.txt` may point to the first web onboarding URL, but it must
  not contain a password.
- Replacing or rotating the appliance CA requires clients to trust the new CA.

## Platform Notes

Windows:

- Import the CA certificate into the current user or local machine trusted root
  store.
- Validate with a browser request to `https://obs.local/` or the appliance
  address after resolving the hostname to the appliance.

macOS:

- Import the CA certificate into Keychain Access.
- Mark the certificate as trusted for SSL.
- Validate with Safari or another browser using the appliance HTTPS URL.

iOS and iPadOS:

- Install the CA certificate profile.
- Enable full trust for the root CA in certificate trust settings.
- Validate with Safari using the appliance HTTPS URL.

Android:

- Install the CA certificate as a user CA.
- Document that some applications and browsers may not trust user CAs.
- Validate with the browser intended for appliance administration.

Linux:

- Install the CA certificate into the distribution trust store.
- Refresh the system CA bundle.
- Validate with a browser or `curl --cacert <ca-cert>`.

Firefox:

- Check whether Firefox uses the system trust store on the target platform.
- If it does not, import the CA into Firefox certificate authorities.
- Validate with the appliance HTTPS URL.

## Validation Matrix

Record platform validation before release:

```text
platform=
version=
browser=
ca_source=
fingerprint_source=
fingerprint_verified=yes|no
import_path=
https_validated=yes|no
notes=
```

Minimum release validation should cover Windows, macOS, iOS or iPadOS, Android,
one Linux desktop, and Firefox trust behavior.
