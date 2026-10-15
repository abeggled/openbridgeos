#!/usr/bin/env sh
set -eu

fail() { echo "host settings fixture failed: $1" >&2; exit 1; }

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM
mkdir -p "${tmp_dir}/bin" "${tmp_dir}/sys/class/net/eth0" "${tmp_dir}/etc/systemd/network" "${tmp_dir}/etc/systemd/timesyncd.conf.d" "${tmp_dir}/log"

cat > "${tmp_dir}/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] && echo 0
EOF
cat > "${tmp_dir}/bin/localectl" <<'EOF'
#!/bin/sh
case "${1:-}" in
  list-keymaps) printf 'ch\nde\nus\n' ;;
  set-keymap) printf '%s\n' "$*" >> "${OBOS_TEST_COMMAND_LOG}" ;;
  *) exit 2 ;;
esac
EOF
for command in systemctl systemd-run hostnamectl; do
  cat > "${tmp_dir}/bin/${command}" <<'EOF'
#!/bin/sh
printf '%s:%s\n' "$(basename "$0")" "$*" >> "${OBOS_TEST_COMMAND_LOG}"
EOF
done
chmod 0755 "${tmp_dir}/bin/"*
: > "${tmp_dir}/commands.log"

run_obosctl() {
  env PATH="${tmp_dir}/bin:${PATH}" \
    OBOS_KEYBOARD_CONFIG_FILE="${tmp_dir}/etc/default/keyboard" \
    OBOS_NETWORK_CONFIG_FILE="${tmp_dir}/etc/systemd/network/10-obos-managed.network" \
    OBOS_TIMESYNCD_CONFIG_FILE="${tmp_dir}/etc/systemd/timesyncd.conf.d/20-obos.conf" \
    OBOS_SYS_CLASS_NET="${tmp_dir}/sys/class/net" \
    OBOS_HOSTS_FILE="${tmp_dir}/etc/hosts" \
    OBOS_SYSTEMD_RUN=systemd-run \
    OBOS_TEST_COMMAND_LOG="${tmp_dir}/commands.log" \
    sh scripts/obosctl "$@"
}

printf '127.0.0.1\tlocalhost\n127.0.1.1\told-host\n' > "${tmp_dir}/etc/hosts"
run_obosctl set-hostname obos-test.a38.ch >/dev/null
grep -Fxq '127.0.1.1	obos-test.a38.ch obos-test' "${tmp_dir}/etc/hosts" || fail "hostname was not synchronized to hosts file"

run_obosctl set-keyboard-layout ch >/dev/null
grep -Fq 'set-keymap ch' "${tmp_dir}/commands.log" || fail "keyboard layout was not applied"

run_obosctl set-network eth0 static 10.38.114.132 255.255.255.0 10.38.114.1 10.38.114.2,1.1.1.1 >/dev/null
network_file="${tmp_dir}/etc/systemd/network/10-obos-managed.network"
grep -Fxq 'Address=10.38.114.132/24' "${network_file}" || fail "static address missing"
grep -Fxq 'Gateway=10.38.114.1' "${network_file}" || fail "gateway missing"
[ "$(grep -Fc 'DNS=' "${network_file}")" -eq 2 ] || fail "DNS servers missing"
grep -Fq -- '--on-active=3s' "${tmp_dir}/commands.log" || fail "network apply was not safely delayed"

if run_obosctl set-network eth0 static invalid 255.255.255.0 10.38.114.1 1.1.1.1 >/dev/null 2>&1; then
  fail "invalid static address was accepted"
fi
if run_obosctl set-network eth0 static 10.38.114.132 255.255.255.0 10.38.115.1 1.1.1.1 >/dev/null 2>&1; then
  fail "gateway outside the configured subnet was accepted"
fi

run_obosctl set-network eth0 dhcp - - - - >/dev/null
grep -Fxq 'DHCP=yes' "${network_file}" || fail "DHCP mode missing"
if grep -Eq '^(Address|Gateway|DNS)=' "${network_file}"; then
  fail "DHCP mode retained static network values"
fi

run_obosctl set-ntp pool.ntp.org,time.cloudflare.com >/dev/null
grep -Fxq 'NTP=pool.ntp.org time.cloudflare.com' "${tmp_dir}/etc/systemd/timesyncd.conf.d/20-obos.conf" || fail "NTP servers missing"
grep -Fq 'systemctl:restart systemd-timesyncd.service' "${tmp_dir}/commands.log" || fail "timesyncd was not restarted"

printf 'apt-get update\napt-get full-upgrade\n' > "${tmp_dir}/update.log"
output="$(OBOS_APPLIANCE_UPDATE_LOG_FILE="${tmp_dir}/update.log" sh scripts/obosctl update-log)"
printf '%s\n' "${output}" | grep -Fq 'log=apt-get full-upgrade' || fail "complete update log is not exposed"

echo "host settings fixture: PASS"
