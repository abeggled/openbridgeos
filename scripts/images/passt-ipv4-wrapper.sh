#!/usr/bin/env sh
set -eu

exec /usr/local/libexec/obos-passt --ipv4-only "$@"
