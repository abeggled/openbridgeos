#!/usr/bin/env sh
set -eu

exec /usr/bin/passt --ipv4-only "$@"
