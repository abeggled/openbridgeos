#!/usr/bin/env sh
set -eu

fail() {
  echo "security check failed: $1" >&2
  exit 1
}

! grep -R --exclude=check-security-defaults.sh "changeme\|password123\|secret123" \
  apps scripts packaging docs README.md SECURITY.md >/dev/null 2>&1 \
  || fail "default placeholder secret found"

grep -q 'APPLIANCE_ID_FILE=' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier path is not defined on first boot"

# shellcheck disable=SC2016
grep -Fq 'uuid > "${APPLIANCE_ID_FILE}"' scripts/bootstrap/first-boot.sh \
  || fail "appliance identifier is not generated on first boot"

grep -q 'APPLIANCE_ID_FILE=' scripts/obosctl \
  || fail "obosctl backup does not know the appliance identifier path"

grep -q 'appliance_id_name' scripts/obosctl \
  || fail "obosctl backup does not include appliance identifier"

grep -q 'obos-backup-manifest.txt' scripts/obosctl \
  || fail "obosctl backup does not include a backup manifest"

grep -q 'contains_secrets=true' scripts/obosctl \
  || fail "obosctl backup manifest does not mark secret-bearing backups"

grep -q 'backup-list)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable backup inventory"

grep -q 'backup-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable backup summary"

grep -q 'format=obos-backup-list-v1' scripts/obosctl \
  || fail "obosctl backup list does not declare a format"

grep -q 'format=obos-backup-summary-v1' scripts/obosctl \
  || fail "obosctl backup summary does not declare a format"

grep -q 'backup_count=' scripts/obosctl \
  || fail "obosctl backup list does not report backup count"

grep -q 'latest_backup_present=' scripts/obosctl \
  || fail "obosctl backup summary does not report latest backup presence"

grep -q 'latest_backup_inspection=' scripts/obosctl \
  || fail "obosctl backup summary does not report latest backup inspection status"

grep -q 'latest_backup_contains_secrets=' scripts/obosctl \
  || fail "obosctl backup summary does not report secret-bearing status"

grep -q 'latest_backup_includes_logs=' scripts/obosctl \
  || fail "obosctl backup summary does not report log inclusion status"

grep -q 'latest_backup_tls_private_keys=' scripts/obosctl \
  || fail "obosctl backup summary does not report TLS private key status"

grep -q 'includes_logs=false' scripts/obosctl \
  || fail "obosctl backup manifest does not record log exclusion"

grep -q -- '--exclude=mqtt/log' scripts/obosctl \
  || fail "obosctl backup does not exclude Mosquitto logs by default"

grep -q 'restore-inspect)' scripts/obosctl \
  || fail "obosctl does not expose restore inspection"

grep -q 'restore-plan)' scripts/obosctl \
  || fail "obosctl does not expose restore planning"

grep -q 'restore-stage)' scripts/obosctl \
  || fail "obosctl does not expose restore staging"

grep -q 'restore-stage-inspect)' scripts/obosctl \
  || fail "obosctl does not expose restore stage inspection"

grep -q 'restore-apply-plan)' scripts/obosctl \
  || fail "obosctl does not expose restore apply planning"

grep -q 'RESTORE_STAGE_DIR=' scripts/obosctl \
  || fail "restore staging does not use a dedicated staging directory"

grep -q 'mode=staged-only' scripts/obosctl \
  || fail "restore staging does not declare staged-only mode"

grep -q 'format=obos-restore-stage-v1' scripts/obosctl \
  || fail "restore staging does not write a stage manifest"

grep -q 'restore stage inspect: PASS' scripts/obosctl \
  || fail "restore stage inspection does not report success"

grep -q 'Mosquitto logs absent' scripts/obosctl \
  || fail "restore stage inspection does not verify log exclusion"

grep -q 'format=obos-restore-apply-plan-v1' scripts/obosctl \
  || fail "restore apply plan does not declare a format"

grep -q 'restore apply plan: blocked; restore stage inspection failed' scripts/obosctl \
  || fail "restore apply plan does not require stage inspection"

grep -q 'require an explicit future apply confirmation flag' scripts/obosctl \
  || fail "restore apply plan does not require explicit confirmation"

# shellcheck disable=SC2016
grep -q 'chmod 0600 "${stage_manifest}"' scripts/obosctl \
  || fail "restore stage manifest permissions are not restrictive"

grep -q 'restore inspect: PASS' scripts/obosctl \
  || fail "restore inspection does not report success"

grep -q 'format=obos-restore-plan-v1' scripts/obosctl \
  || fail "restore plan does not declare a format"

grep -q 'mode=non-destructive' scripts/obosctl \
  || fail "restore plan does not declare non-destructive mode"

grep -q 'restore preserves appliance TLS identity' scripts/obosctl \
  || fail "restore plan does not explain TLS identity impact"

grep -q 'unsafe absolute or parent-relative paths' scripts/obosctl \
  || fail "restore inspection does not reject unsafe archive paths"

grep -q 'TLS private key material present' scripts/obosctl \
  || fail "restore inspection does not report TLS identity material"

grep -q 'LAST_UPDATE_FILE=' scripts/obosctl \
  || fail "obosctl update does not track last update state"

grep -q 'format=obos-update-v1' scripts/obosctl \
  || fail "obosctl update state does not declare a format"

grep -q 'update-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable update status"

grep -q 'update-rollback-plan)' scripts/obosctl \
  || fail "obosctl does not expose a last-update rollback plan"

grep -q 'format=obos-update-summary-v1' scripts/obosctl \
  || fail "obosctl update summary does not declare a format"

grep -q 'format=obos-update-rollback-plan-v1' scripts/obosctl \
  || fail "obosctl update rollback plan does not declare a format"

grep -q 'last_update_present=' scripts/obosctl \
  || fail "obosctl update summary does not report update presence"

grep -q 'health_https_proxy=ok' scripts/obosctl \
  || fail "obosctl update state does not record HTTPS proxy health"

grep -q 'pre_update_backup_required=true' scripts/obosctl \
  || fail "obosctl update state does not record pre-update backup requirement"

grep -q 'pre_update_backup_created=true' scripts/obosctl \
  || fail "obosctl update state does not record pre-update backup creation"

grep -q 'update: blocked; pre-update backup was not created' scripts/obosctl \
  || fail "obosctl update does not block when the pre-update backup is missing"

grep -q 'update rollback plan: blocked; backup inspection failed' scripts/obosctl \
  || fail "obosctl update rollback plan does not require backup inspection"

grep -q 'restore-apply-plan <stage-dir>' scripts/obosctl \
  || fail "obosctl update rollback plan does not end with restore apply planning"

grep -q 'last-update:' scripts/obosctl \
  || fail "obosctl status does not show last update state"

grep -q 'status-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable status"

grep -q 'format=obos-status-summary-v1' scripts/obosctl \
  || fail "obosctl status summary does not declare a format"

# shellcheck disable=SC2016
grep -Fq 'health_https_proxy=${health_https_proxy}' scripts/obosctl \
  || fail "obosctl status summary does not report HTTPS proxy health"

grep -q 'check-web-ui-agent-contract.sh' .github/workflows/ci.yml \
  || fail "CI does not validate the web UI agent contract"

grep -q 'check-obos-agent.sh' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent"

grep -q 'sudo visudo -cf packaging/sudoers/obos-agent' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent sudoers syntax"

grep -q 'sudo logrotate --debug packaging/logrotate/obos-agent' .github/workflows/ci.yml \
  || fail "CI does not validate obos-agent logrotate syntax"

grep -q 'sudo' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install sudo for the agent privilege boundary"

grep -q 'logrotate' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install logrotate for agent audit logs"

grep -q 'useradd .*obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not create the obos-agent system user"

# shellcheck disable=SC2016
grep -q 'install -m 0440 "${REPO_ROOT}/packaging/sudoers/obos-agent" /etc/sudoers.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install the obos-agent sudoers policy"

# shellcheck disable=SC2016
grep -q 'install -m 0644 "${REPO_ROOT}/packaging/logrotate/obos-agent" /etc/logrotate.d/obos-agent' scripts/bootstrap/provision-debian.sh \
  || fail "provisioning does not install the obos-agent logrotate policy"

grep -q 'obos-agent ALL=(root) NOPASSWD:' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not use an allowlisted root boundary"

grep -q 'create 0640 obos-agent obos-agent' packaging/logrotate/obos-agent \
  || fail "obos-agent logrotate policy does not preserve restrictive ownership"

grep -q 'format=obos-agent-response-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare a response format"

grep -q 'format=obos-agent-actions-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare an action inventory format"

grep -q 'format=obos-agent-audit-v1' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not declare a mutation audit format"

grep -q 'OBOS_AGENT_AUDIT_LOG' scripts/agent/obos-agent.sh \
  || fail "obos-agent audit log path is not configurable"

grep -q 'write_audit_log' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not audit mutating actions"

# shellcheck disable=SC2016
grep -q 'sudo -n "${OBOSCTL}"' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not use non-interactive sudo for obosctl"

grep -q 'action=status-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark read-only actions"

grep -q 'action=update-rollback-plan|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark update rollback planning as read-only"

grep -q 'action=backup-summary|mutating=false' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark backup summary as read-only"

grep -q 'action=start|mutating=true|confirm=start' scripts/agent/obos-agent.sh \
  || fail "obos-agent action inventory does not mark confirmed mutations"

grep -q '/usr/bin/obosctl update-rollback-plan' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow update rollback planning"

grep -q '/usr/bin/obosctl backup-summary' packaging/sudoers/obos-agent \
  || fail "obos-agent sudoers policy does not allow backup summary"

grep -q 'require_no_extra_args' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not reject extra arguments"

grep -q 'require_confirm_args' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not require confirmation for mutations"

grep -q 'validate_source_cidr' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not validate MQTT source CIDR before sudo"

# shellcheck disable=SC2016
grep -q 'timeout "${timeout_seconds}"' scripts/agent/obos-agent.sh \
  || fail "obos-agent does not enforce command timeouts"

grep -q 'proxy-health)' scripts/obosctl \
  || fail "obosctl does not expose verified HTTPS proxy health"

grep -q 'PROXY_HEALTH_HOST=' scripts/obosctl \
  || fail "obosctl proxy health does not use an explicit TLS hostname"

grep -q -- '--cacert' scripts/obosctl \
  || fail "obosctl proxy health does not verify the local CA"

grep -q -- '--resolve' scripts/obosctl \
  || fail "obosctl proxy health does not resolve the TLS hostname locally"

grep -q 'APPLIANCE_ID_FILE=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit appliance identifier"

grep -q 'security-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable security baseline status"

grep -q 'format=obos-security-baseline-summary-v1' scripts/audit/security-baseline.sh \
  || fail "security baseline does not expose a summary format"

grep -q 'fail_count=' scripts/audit/security-baseline.sh \
  || fail "security baseline summary does not report failure count"

grep -q 'PROXY_HEALTH_HOST=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify HTTPS proxy hostname"

grep -q -- '--cacert' scripts/audit/security-baseline.sh \
  || fail "security baseline does not verify HTTPS proxy local CA trust"

grep -q 'NGINX_PROXY_CONF=' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx reverse proxy config"

grep -q 'server_tokens off;' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx server token disclosure"

grep -q 'client_header_timeout 30s;' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit nginx client header timeout"

grep -q 'check_obos_systemd_hardening obos-first-boot.service' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit first boot systemd hardening"

grep -q 'check_obos_systemd_hardening obos-openbridgeserver.service' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit open bridge server systemd hardening"

grep -q 'NoNewPrivileges yes' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit systemd NoNewPrivileges"

grep -q 'SystemCallArchitectures native' scripts/audit/security-baseline.sh \
  || fail "security baseline does not audit systemd syscall architecture"

grep -q 'OBS_HTTP_HOST_PORT=127.0.0.1:8080' scripts/bootstrap/first-boot.sh \
  || fail "open bridge server HTTP is not localhost-only by default"

grep -q 'OBS_MQTT_HOST_PORT=127.0.0.1:1883' scripts/bootstrap/first-boot.sh \
  || fail "MQTT plain listener is not localhost by default"

grep -q 'OBS_MQTT_WS_HOST_PORT=127.0.0.1:9001' scripts/bootstrap/first-boot.sh \
  || fail "MQTT websocket listener is not localhost by default"

# shellcheck disable=SC2016
grep -Fq 'OBS_JWT_SECRET=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "OBS JWT secret is not generated on first boot"

# shellcheck disable=SC2016
grep -Fq 'OBS_MQTT_PASSWORD=$(secret)' scripts/bootstrap/first-boot.sh \
  || fail "MQTT password is not generated on first boot"

grep -q 'TLS_GENERATE_SCRIPT=' scripts/bootstrap/first-boot.sh \
  || fail "TLS material is not generated on first boot"

grep -q 'BOOT_TRUST_SCRIPT=' scripts/bootstrap/first-boot.sh \
  || fail "boot-accessible TLS trust summary is not exported on first boot"

grep -q 'nginx-light' scripts/bootstrap/provision-debian.sh \
  || fail "nginx reverse proxy package is not installed during provisioning"

grep -q 'unattended-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "unattended security upgrade package is not installed during provisioning"

grep -q '20auto-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "apt periodic unattended upgrade config is not installed"

grep -q '50unattended-upgrades' scripts/bootstrap/provision-debian.sh \
  || fail "unattended upgrade policy config is not installed"

grep -q 'apt-daily-upgrade.timer' scripts/bootstrap/provision-debian.sh \
  || fail "apt unattended upgrade timer is not enabled"

grep -q 'Unattended-Upgrade "1"' packaging/apt/20auto-upgrades \
  || fail "apt periodic unattended upgrades are not enabled"

grep -q 'Debian-Security' packaging/apt/50unattended-upgrades \
  || fail "unattended upgrades are not restricted to Debian security origins"

grep -q 'Automatic-Reboot "false"' packaging/apt/50unattended-upgrades \
  || fail "unattended upgrades allow automatic reboot"

grep -q 'OBOS_IMAGE_DEFAULT_SSH=disabled' packaging/images/profiles/rpi4-arm64.env \
  || fail "Raspberry Pi image profile does not disable SSH by default"

grep -q 'expect_value ssh_default disabled' scripts/images/check-rpi-image-manifest.sh \
  || fail "Raspberry Pi image manifest does not record disabled SSH by default"

grep -q 'systemctl enable nginx.service' scripts/bootstrap/provision-debian.sh \
  || fail "nginx service is not enabled during provisioning"

grep -q 'set-mqtt-lan-access.sh' scripts/bootstrap/provision-debian.sh \
  || fail "MQTT LAN opt-in helper is not installed during provisioning"

grep -q 'OBOS_MQTT_LAN_SOURCE_CIDR' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support source CIDR restriction"

grep -q 'is_ipv4_cidr' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not validate IPv4 CIDR numerically"

grep -q 'export-boot-trust-summary.sh' scripts/bootstrap/provision-debian.sh \
  || fail "boot trust summary helper is not installed during provisioning"

grep -q 'check-tls-status.sh' scripts/bootstrap/provision-debian.sh \
  || fail "TLS status helper is not installed during provisioning"

grep -q '"no-new-privileges": true' packaging/docker/daemon.json \
  || fail "Docker no-new-privileges default is not enabled"

grep -q '"log-driver": "local"' packaging/docker/daemon.json \
  || fail "Docker local log driver is not configured"

grep -q 'policy drop' packaging/nftables/obos.nft \
  || fail "nftables input policy is not default-drop"

grep -q 'tcp dport 443 accept' packaging/nftables/obos.nft \
  || fail "HTTPS reverse proxy port is not allowed"

! grep -q 'tcp dport 8080 accept' packaging/nftables/obos.nft \
  || fail "Direct open bridge server HTTP is open in the default firewall"

grep -q 'HOST_HTTP_PORT=' scripts/images/smoke-test-amd64-qcow2.sh \
  || fail "qcow2 smoke test does not probe direct open bridge server HTTP"

grep -q 'direct open bridge server HTTP is reachable' scripts/images/smoke-test-amd64-qcow2.sh \
  || fail "qcow2 smoke test does not fail when direct HTTP is reachable"

! grep -q 'tcp dport 1883 accept' packaging/nftables/obos.nft \
  || fail "MQTT plain TCP is open in the default firewall"

! grep -q 'tcp dport 9001 accept' packaging/nftables/obos.nft \
  || fail "MQTT WebSocket is open in the default firewall"

grep -q 'OBOS MQTT LAN BEGIN' packaging/nftables/obos.nft \
  || fail "nftables MQTT LAN managed block is missing"

grep -q 'tcp dport 1883 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT plain TCP when enabled"

grep -q 'tcp dport 9001 accept' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not open MQTT WebSocket when enabled"

grep -q 'ip saddr %s' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support IPv4 source-restricted firewall rules"

grep -q 'ip6 saddr %s' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not support IPv6 source-restricted firewall rules"

grep -q 'OBS_MQTT_HOST_PORT 0.0.0.0:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not publish MQTT plain TCP when enabled"

grep -q 'OBS_MQTT_HOST_PORT 127.0.0.1:1883' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not restore localhost MQTT plain TCP"

grep -q 'udp sport 67 udp dport 68 accept' packaging/nftables/obos.nft \
  || fail "DHCPv4 client renewals are not allowed"

grep -q 'udp sport 547 udp dport 546 accept' packaging/nftables/obos.nft \
  || fail "DHCPv6 client renewals are not allowed"

! grep -q 'tcp dport 22 accept' packaging/nftables/obos.nft \
  || fail "SSH is open in the default firewall"

# shellcheck disable=SC2016
grep -Fq 'DISABLE_SSH="${OBOS_DISABLE_SSH:-1}"' scripts/hardening/apply-host-hardening.sh \
  || fail "SSH disablement is not the default hardening behavior"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing NoNewPrivileges"

grep -q 'ProtectSystem=full' packaging/systemd/obos-first-boot.service \
  || fail "first boot systemd unit is missing filesystem protection"

grep -q 'NoNewPrivileges=true' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit is missing NoNewPrivileges"

grep -q 'ProtectSystem=full' packaging/systemd/obos-openbridgeserver.service \
  || fail "open bridge server systemd unit is missing filesystem protection"

grep -q 'ssl_certificate /etc/obos/tls/obos.local.crt;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not use obos TLS certificate"

grep -q 'proxy_pass http://127.0.0.1:8080;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not target localhost OBS"

grep -q 'server_tokens off;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy exposes server tokens"

grep -q 'client_body_timeout 30s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound client body timeout"

grep -q 'client_header_timeout 30s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound client header timeout"

grep -q 'send_timeout 60s;' packaging/nginx/openbridgeserver.conf \
  || fail "nginx reverse proxy does not bound send timeout"

grep -q 'no-new-privileges:true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not set no-new-privileges"

grep -q 'init: true' apps/openbridgeserver/compose.yaml \
  || fail "Compose services do not enable init process handling"

grep -q 'pids_limit: 128' apps/openbridgeserver/compose.yaml \
  || fail "Mosquitto container does not limit process count"

grep -q 'pids_limit: 256' apps/openbridgeserver/compose.yaml \
  || fail "open bridge server container does not limit process count"

grep -q 'TLS_DIR=' scripts/obosctl \
  || fail "obosctl backup does not know the TLS material directory"

grep -q 'backup includes TLS private key material' scripts/obosctl \
  || fail "obosctl backup does not warn about TLS private key material"

grep -q 'mqtt-enable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN enablement"

grep -q 'mqtt-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable MQTT status"

grep -q 'format=obos-mqtt-summary-v1' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT LAN helper does not expose a summary format"

grep -q 'lan_enabled=' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT summary does not report LAN exposure"

grep -q 'firewall_source=' scripts/hardening/set-mqtt-lan-access.sh \
  || fail "MQTT summary does not report firewall source scope"

grep -q 'mqtt-disable-lan)' scripts/obosctl \
  || fail "obosctl does not expose MQTT LAN disablement"

grep -q 'basicConstraints=critical,CA:TRUE,pathlen:0' scripts/tls/generate-tls-material.sh \
  || fail "local CA is not generated with critical CA constraints"

grep -q 'TLS material already exists' scripts/tls/generate-tls-material.sh \
  || fail "TLS material generation is not idempotent"

grep -q 'ca_created' scripts/tls/generate-tls-material.sh \
  || fail "TLS idempotency does not account for CA regeneration"

grep -q 'No private keys were exported.' scripts/tls/export-trust-bundle.sh \
  || fail "TLS trust export does not state that private keys are excluded"

grep -q 'tls-export)' scripts/obosctl \
  || fail "obosctl does not expose TLS trust export"

grep -q 'tls-status)' scripts/obosctl \
  || fail "obosctl does not expose TLS status checks"

grep -q 'tls-summary)' scripts/obosctl \
  || fail "obosctl does not expose machine-readable TLS trust status"

grep -q 'format=obos-tls-summary-v1' scripts/tls/check-tls-status.sh \
  || fail "TLS status helper does not expose a summary format"

grep -q '_sha256_fingerprint=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report certificate fingerprints"

grep -q '_expiry_state=' scripts/tls/check-tls-status.sh \
  || fail "TLS summary does not report certificate expiry state"

grep -q 'tls-export-boot)' scripts/obosctl \
  || fail "obosctl does not expose boot trust summary export"

grep -q 'No private keys were exported to the boot partition.' scripts/tls/export-boot-trust-summary.sh \
  || fail "boot trust summary export does not state that private keys are excluded"

# shellcheck disable=SC2016
grep -q 'openssl x509 -in "${cert}" -noout -checkend' scripts/tls/check-tls-status.sh \
  || fail "TLS status helper does not check certificate expiry"
