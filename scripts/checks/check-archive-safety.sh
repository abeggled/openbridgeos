#!/usr/bin/env sh
set -eu

OBOSCTL="scripts/obosctl"

fail() {
  echo "archive safety fixture failed: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
source_dir="${tmp_dir}/source"
mkdir -p "${source_dir}/data" "${source_dir}/mqtt"
printf 'format=obos-backup-v1\n' > "${source_dir}/obos-backup-manifest.txt"
printf 'test-appliance\n' > "${source_dir}/appliance-id"
printf 'OBS_JWT_SECRET=test\n' > "${source_dir}/openbridgeserver.env"
printf 'services: {}\n' > "${source_dir}/compose.yaml"
printf 'listener 1883\n' > "${source_dir}/mosquitto.conf"

safe_archive="${tmp_dir}/safe.tar.gz"
tar -czf "${safe_archive}" -C "${source_dir}" \
  obos-backup-manifest.txt appliance-id openbridgeserver.env data mqtt compose.yaml mosquitto.conf
sh "${OBOSCTL}" restore-inspect "${safe_archive}" >/dev/null \
  || fail "safe backup archive was rejected"

ln -s /etc "${source_dir}/data/host-etc"
link_archive="${tmp_dir}/link.tar.gz"
tar -czf "${link_archive}" -C "${source_dir}" \
  obos-backup-manifest.txt appliance-id openbridgeserver.env data mqtt compose.yaml mosquitto.conf
if sh "${OBOSCTL}" restore-inspect "${link_archive}" >/dev/null 2>&1; then
  fail "backup archive containing a symbolic link was accepted"
fi

duplicate_archive="${tmp_dir}/duplicate.tar.gz"
tar -czf "${duplicate_archive}" -C "${source_dir}" \
  obos-backup-manifest.txt obos-backup-manifest.txt appliance-id openbridgeserver.env mqtt compose.yaml mosquitto.conf
if sh "${OBOSCTL}" restore-inspect "${duplicate_archive}" >/dev/null 2>&1; then
  fail "backup archive containing duplicate members was accepted"
fi

if OBOS_RESTORE_MAX_UNPACKED_BYTES=1 sh "${OBOSCTL}" restore-inspect "${safe_archive}" >/dev/null 2>&1; then
  fail "backup archive exceeding the configured expanded-size limit was accepted"
fi

portable_dir="${tmp_dir}/portable"
mkdir -p "${portable_dir}/source"
printf 'format=obos-portable-backup-v1\n' > "${portable_dir}/source/metadata.txt"
ln -s /etc/passwd "${portable_dir}/source/payload.tar.gz.gpg"
portable_archive="${portable_dir}/unsafe.tar"
tar -cf "${portable_archive}" -C "${portable_dir}/source" metadata.txt payload.tar.gz.gpg
printf 'passphrase\n' > "${tmp_dir}/passphrase"
mock_bin="${tmp_dir}/bin"
mkdir -p "${mock_bin}"
cat > "${mock_bin}/id" <<'EOF'
#!/usr/bin/env sh
[ "${1:-}" = "-u" ] && printf '0\n'
EOF
chmod 0755 "${mock_bin}/id"
if PATH="${mock_bin}:${PATH}" OBOS_PORTABLE_IMPORT_DIR="${portable_dir}" \
  sh "${OBOSCTL}" portable-import-stage "${portable_archive}" "${tmp_dir}/passphrase" >/dev/null 2>&1; then
  fail "portable archive containing a symbolic link was accepted"
fi

echo "archive safety fixture: PASS"
