# Security Policy

open bridge operating system is intended to run building automation infrastructure. Security
issues should be treated as high impact even when the affected system is
deployed only on a local network.

## Supported Versions

The project is in early bootstrap. No stable release is supported yet.

Once public images exist, supported versions will be listed here with their
security update status.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub Security
Advisories once this repository is configured for them.

Until then, contact the maintainer directly and avoid opening public issues for
vulnerabilities that expose secrets, authentication bypasses, remote execution,
unsafe update paths, or container breakout risks.

## Security Expectations

The project should avoid:

- default production secrets
- unauthenticated administrative APIs
- silent remote update execution
- externally exposed MQTT by default
- writable application definitions through the web UI
- leaking credentials in logs or diagnostics bundles

Security-sensitive changes should document their threat model in the pull
request or adjacent design documentation.
