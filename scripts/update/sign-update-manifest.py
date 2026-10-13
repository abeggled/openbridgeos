#!/usr/bin/env python3
"""Sign an update manifest with a password-protected Minisign key in CI."""

import os
import sys

import pexpect


REQUIRED_ENVIRONMENT = (
    "OBOS_RELEASE_MINISIGN_PASSWORD",
    "OBOS_SIGN_KEY_FILE",
    "OBOS_SIGN_MANIFEST",
    "OBOS_SIGN_TRUSTED_COMMENT",
)


def main() -> int:
    missing = [name for name in REQUIRED_ENVIRONMENT if not os.environ.get(name)]
    if missing:
        print(f"missing required environment variable: {missing[0]}", file=sys.stderr)
        return 2

    child = pexpect.spawn(
        "minisign",
        [
            "-Sm",
            os.environ["OBOS_SIGN_MANIFEST"],
            "-s",
            os.environ["OBOS_SIGN_KEY_FILE"],
            "-t",
            os.environ["OBOS_SIGN_TRUSTED_COMMENT"],
        ],
        encoding="utf-8",
        timeout=120,
    )
    try:
        child.expect_exact("Password: ")
        child.sendline(os.environ["OBOS_RELEASE_MINISIGN_PASSWORD"])
        child.expect(pexpect.EOF)
        child.close()
    except (pexpect.EOF, pexpect.TIMEOUT) as error:
        child.close(force=True)
        print(f"Minisign signing failed: {type(error).__name__}", file=sys.stderr)
        return 1

    return child.exitstatus if child.exitstatus is not None else 1


if __name__ == "__main__":
    raise SystemExit(main())
