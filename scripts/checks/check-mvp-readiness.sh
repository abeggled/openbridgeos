#!/usr/bin/env sh
set -eu

fail() {
  echo "mvp readiness check failed: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

require_line() {
  expected="$1"
  file="$2"
  grep -Fq -- "${expected}" "${file}" \
    || fail "missing '${expected}' in ${file}"
}

require_file README.md
require_file README.de.md
require_file docs/roadmap.md
require_file docs/image-build.md
require_file docs/image-release-validation.md
require_file docs/release-signing.md
require_file docs/release-notes-template.md
require_file docs/technical-mvp-handoff.md
require_file docs/mvp-validation-log.md
require_file docs/tls-certificate-lifecycle.md
require_file docs/client-ca-trust.md
require_file docs/security-baseline-testplan.md
require_file scripts/obosctl
require_file scripts/agent/obos-agent.sh
require_file scripts/agent/obos-agent-http.py
require_file scripts/auth/generate-web-auth.sh
require_file scripts/audit/mvp-runtime-readiness.sh
require_file scripts/checks/check-mvp-runtime-readiness.sh
require_file apps/obos-web/index.html
require_file apps/obos-web/app.js
require_file packaging/images/profiles/amd64-vm.env
require_file packaging/images/profiles/rpi4-arm64.env
require_file scripts/images/build-amd64-qcow2.sh
require_file scripts/images/check-amd64-qcow2-build-host.sh
require_file scripts/images/build-rpi4-arm64-image.sh
require_file scripts/checks/check-image-profiles.sh
require_file scripts/images/smoke-test-amd64-qcow2.sh
require_file scripts/images/check-rpi-boot-files.sh
require_file scripts/images/check-image-release-validation-record.sh
require_file scripts/images/print-image-validation-record-template.sh
require_file scripts/images/check-release-candidate.sh
require_file scripts/images/check-release-evidence-bundle.sh
require_file scripts/images/check-compose-image-pinning.sh
require_file scripts/images/print-image-build-plan.sh
require_file scripts/tls/plan-leaf-renewal.sh
require_file scripts/tls/renew-leaf-certificate.sh

require_line "Debian 13 Trixie" README.md
require_line "Raspberry Pi 4+" README.md
require_line "x86_64" README.md
require_line "security-focused" README.md

require_line "Build a Debian-based x86_64 image." docs/roadmap.md
require_line "Build ARM64 image." docs/roadmap.md
require_line "Static obos web shell is installed" docs/roadmap.md
require_line "Start, stop, restart, update, backup creation, and restore staging" docs/roadmap.md
require_line "Encrypted portable backup export creation exists in" docs/roadmap.md
require_line "image-release-validation.md" docs/roadmap.md
require_line "release-signing.md" docs/roadmap.md
require_line "release-notes-template.md" docs/roadmap.md
require_line "technical-mvp-handoff.md" docs/roadmap.md
require_line "tls-certificate-lifecycle.md" docs/roadmap.md
require_line "implemented as a confirmed CLI-only workflow" docs/roadmap.md
require_line "mvp-validation-log.md" docs/technical-mvp-handoff.md
require_line "2026-06-08 amd64 qcow2 Smoke Pass" docs/mvp-validation-log.md
require_line "qcow2 smoke test: PASS" docs/mvp-validation-log.md

require_line "format=obos-status-summary-v1" scripts/obosctl
require_line "format=obos-system-summary-v1" scripts/obosctl
require_line "format=obos-set-hostname-v1" scripts/obosctl
require_line "format=obos-set-timezone-v1" scripts/obosctl
require_line "format=obos-update-summary-v1" scripts/obosctl
require_line "format=obos-backup-summary-v1" scripts/obosctl
require_line "format=obos-restore-stage-summary-v1" scripts/obosctl
require_line "format=obos-restore-apply-v1" scripts/obosctl
require_line "format=obos-logs-tail-v1" scripts/obosctl
require_line "format=obos-mqtt-summary-v1" scripts/hardening/set-mqtt-lan-access.sh
require_line "format=obos-tls-summary-v1" scripts/tls/check-tls-status.sh
require_line "format=obos-tls-leaf-renewal-plan-v1" scripts/tls/plan-leaf-renewal.sh
require_line "confirmed_command=sudo obosctl tls-renew-leaf --confirm tls-renew-leaf" scripts/tls/plan-leaf-renewal.sh
require_line "format=obos-tls-leaf-renewal-v1" scripts/tls/renew-leaf-certificate.sh
require_line "format=obos-security-baseline-summary-v1" scripts/audit/security-baseline.sh
require_line "STATE_DIR=" scripts/audit/security-baseline.sh
require_line "WEB_AUTH_FILE=" scripts/audit/security-baseline.sh
require_line "check_web_auth" scripts/audit/security-baseline.sh
require_line "format=obos-mvp-runtime-readiness-v1" scripts/audit/mvp-runtime-readiness.sh
require_line "check_systemd_active obos-agent-http.service" scripts/audit/mvp-runtime-readiness.sh
require_line "check_output_contains \"security baseline passes\" \"result=PASS\"" scripts/audit/mvp-runtime-readiness.sh
require_line "check_update_rollback_plan_if_available" scripts/audit/mvp-runtime-readiness.sh
require_line "update rollback plan available for last update" scripts/audit/mvp-runtime-readiness.sh
require_line "TLS leaf renewal plan available" scripts/audit/mvp-runtime-readiness.sh
require_line "check_http_agent_status" scripts/audit/mvp-runtime-readiness.sh
require_line "agent does not expose restore apply mutation" scripts/audit/mvp-runtime-readiness.sh
require_line "runtime readiness accepted restore apply mutation exposure" scripts/checks/check-mvp-runtime-readiness.sh
# shellcheck disable=SC2016
require_line 'install -m 0755 "${REPO_ROOT}/scripts/audit/mvp-runtime-readiness.sh" "${OBOS_LIB_DIR}/mvp-runtime-readiness.sh"' scripts/bootstrap/provision-debian.sh
require_line "MVP_READINESS_SCRIPT=" scripts/obosctl
require_line "mvp-readiness-summary)" scripts/obosctl
require_line "format=obos-portable-backup-export-plan-v1" scripts/obosctl
require_line "format=obos-portable-backup-export-v1" scripts/obosctl
require_line "format=obos-portable-backup-import-plan-v1" scripts/obosctl
require_line "format=obos-portable-import-stage-v1" scripts/obosctl
require_line "gpg --batch --yes --pinentry-mode loopback" scripts/obosctl
require_line "--confirm restore-apply" scripts/obosctl

require_line "action=start|mutating=true|confirm=start" scripts/agent/obos-agent.sh
require_line "action=stop|mutating=true|confirm=stop" scripts/agent/obos-agent.sh
require_line "action=restart|mutating=true|confirm=restart" scripts/agent/obos-agent.sh
require_line "action=update|mutating=true|confirm=update" scripts/agent/obos-agent.sh
require_line "action=backup|mutating=true|confirm=backup" scripts/agent/obos-agent.sh
require_line "action=restore-stage|mutating=true|confirm=restore-stage|required_arg=backup-path" scripts/agent/obos-agent.sh
require_line "agent exposed restore apply mutation" scripts/checks/check-obos-agent.sh
require_line "action=portable-export|mutating=true|confirm=portable-export|required_arg=backup-path|required_arg=passphrase-file" scripts/agent/obos-agent.sh
require_line "action=portable-import-stage|mutating=true|confirm=portable-import-stage|required_arg=portable-backup|required_arg=passphrase-file" scripts/agent/obos-agent.sh
require_line "action=portable-export-plan|mutating=false|required_arg=backup-path" scripts/agent/obos-agent.sh
require_line "action=portable-import-plan|mutating=false|required_arg=portable-backup" scripts/agent/obos-agent.sh
require_line "action=logs-tail|mutating=false" scripts/agent/obos-agent.sh
require_line "action=mvp-readiness-summary|mutating=false" scripts/agent/obos-agent.sh
require_line "action=set-hostname|mutating=true|confirm=set-hostname|required_arg=hostname" scripts/agent/obos-agent.sh
require_line "action=set-timezone|mutating=true|confirm=set-timezone|required_arg=timezone" scripts/agent/obos-agent.sh

require_line '"backup": "backup"' scripts/agent/obos-agent-http.py
require_line '"portable-export": "portable-export"' scripts/agent/obos-agent-http.py
require_line '"portable-import-stage": "portable-import-stage"' scripts/agent/obos-agent-http.py
require_line '"restore-stage": "restore-stage"' scripts/agent/obos-agent-http.py
require_line "HTTP bridge exposed restore apply mutation" scripts/checks/check-obos-agent-http.sh
require_line '"update": "update"' scripts/agent/obos-agent-http.py
require_line '"logs-tail"' scripts/agent/obos-agent-http.py
require_line '"mvp-readiness-summary"' scripts/agent/obos-agent-http.py
require_line '"mqtt-enable-lan": "mqtt-enable-lan"' scripts/agent/obos-agent-http.py
require_line '"mqtt-disable-lan": "mqtt-disable-lan"' scripts/agent/obos-agent-http.py
require_line '"tls-generate": "tls-generate"' scripts/agent/obos-agent-http.py
require_line '"tls-export": "tls-export"' scripts/agent/obos-agent-http.py
require_line '"set-hostname": "set-hostname"' scripts/agent/obos-agent-http.py
require_line '"set-timezone": "set-timezone"' scripts/agent/obos-agent-http.py
require_line "MAX_POST_BYTES = 1024" scripts/agent/obos-agent-http.py
require_line "Access-Control-Allow-Origin" scripts/checks/check-obos-agent-http.sh
require_line "auth_basic \"open bridge operating system\";" packaging/nginx/openbridgeserver.conf
require_line "auth_basic_user_file /etc/obos/web.htpasswd;" packaging/nginx/openbridgeserver.conf
require_line "openssl passwd -apr1 -stdin" scripts/auth/generate-web-auth.sh
require_line "web-auth-rotate)" scripts/obosctl
require_line "action=web-auth-rotate|mutating=true|confirm=web-auth-rotate" scripts/agent/obos-agent.sh
require_line '"web-auth-rotate": "web-auth-rotate"' scripts/agent/obos-agent-http.py
require_line "OBOS-ONBOARDING.txt" scripts/tls/export-boot-trust-summary.sh
require_line "initial web console password" scripts/tls/export-boot-trust-summary.sh
require_line "Validation Matrix" docs/client-ca-trust.md
require_line "fingerprint_verified=yes|no" docs/client-ca-trust.md
require_line "tls-certificate-lifecycle.md" docs/tls-trust.md
require_line "confirmed CLI leaf" docs/admin-cli.md
require_line "Leaf Renewal" docs/tls-certificate-lifecycle.md
require_line "tls-renew-leaf-plan" docs/tls-certificate-lifecycle.md
require_line "Local CA Rotation" docs/tls-certificate-lifecycle.md
require_line "Imported Public Certificate" docs/tls-certificate-lifecycle.md
require_line "client_reonboarding_required=yes|no" docs/tls-certificate-lifecycle.md
require_line "tls-renew-leaf-plan)" scripts/obosctl
require_line "tls-renew-leaf)" scripts/obosctl
require_line "TLS_LEAF_RENEWAL_PLAN_SCRIPT=" scripts/obosctl
require_line "TLS_LEAF_RENEWAL_SCRIPT=" scripts/obosctl
require_line "plan-leaf-renewal.sh" scripts/bootstrap/provision-debian.sh
require_line "renew-leaf-certificate.sh" scripts/bootstrap/provision-debian.sh
require_line "TLS leaf renewal is intentionally not exposed through the HTTP bridge or web UI" docs/web-ui-agent-contract.md
require_line "Raspberry Pi Network Installer" docs/image-release-validation.md
require_line "CONFIG_BLK_DEV_NVME=y" docs/image-release-validation.md
require_line "sudo obosctl tls-renew-leaf-plan" docs/image-release-validation.md
require_line "update-rollback-stage" docs/image-release-validation.md
require_line "format=obos-image-release-validation-v1" docs/image-release-validation.md
require_line "signature_verified=yes|no" docs/image-release-validation.md
require_line "tls_leaf_renewal_plan_result=PASS|FAIL" docs/image-release-validation.md
require_line "print-image-validation-record-template.sh amd64-vm" docs/image-release-validation.md
require_line "record checker rejects unfinished" docs/image-release-validation.md
require_line "check-release-candidate.sh" docs/image-release-validation.md
require_line "OBOS_REQUIRE_PINNED_IMAGES=1 scripts/images/check-compose-image-pinning.sh" docs/image-release-validation.md
require_line "expect_value debian_release trixie" scripts/images/check-qcow2-manifest.sh
require_line "expect_value provision_script scripts/bootstrap/provision-debian.sh" scripts/images/check-rpi-image-manifest.sh
require_line "require_value rollback_stage_result PASS" scripts/images/check-image-release-validation-record.sh
require_line "require_value tls_leaf_renewal_plan_result PASS" scripts/images/check-image-release-validation-record.sh
require_line "still contains a template placeholder" scripts/images/check-image-release-validation-record.sh
require_line "require_present notes" scripts/images/check-image-release-validation-record.sh
require_line "MINISIGN_PUBLIC_KEY=" scripts/images/check-release-manifest.sh
require_line "minisign -Vm" scripts/images/check-release-manifest.sh
require_line "amd64-vm release artifact missing" scripts/images/check-release-manifest.sh
require_line "rpi4-arm64 release artifact missing" scripts/images/check-release-manifest.sh
require_line "duplicate release artifact profile" scripts/images/check-release-manifest.sh
require_line "Release private key" docs/release-signing.md
require_line "Do not inject the private key into CI" docs/release-signing.md
require_line "OBOS_RELEASE_MINISIGN_PUBLIC_KEY" docs/release-signing.md
require_line "cross-checks validation records against the" docs/release-signing.md
require_line "release-notes-template.md" docs/release-signing.md
require_line "release notes include the required validation records and known gaps" docs/release-signing.md
require_line "format=obos-release-candidate-check-v1" scripts/images/check-release-candidate.sh
require_line "amd64-vm validation record missing" scripts/images/check-release-candidate.sh
require_line "rpi4-arm64 validation record missing" scripts/images/check-release-candidate.sh
require_line "validation record does not match release manifest artifact" scripts/images/check-release-candidate.sh
require_line "duplicate amd64-vm validation record" scripts/images/check-release-candidate.sh
require_line "release candidate must have exactly two validation records" scripts/images/check-release-candidate.sh
require_line "format=obos-compose-image-pinning-v1" scripts/images/check-compose-image-pinning.sh
require_line "OBOS_REQUIRE_PINNED_IMAGES" scripts/images/check-compose-image-pinning.sh
require_line "OBOS_REQUIRE_PINNED_IMAGES=1" docs/hardening.md
require_line "OBOS_RELEASE_BUILD=1" docs/technical-mvp-handoff.md
require_line "check-release-candidate.sh" docs/technical-mvp-handoff.md
require_line "CONFIG_BLK_DEV_NVME=y" docs/technical-mvp-handoff.md
require_line "release-notes-template.md" docs/technical-mvp-handoff.md
require_line "print-image-build-plan.sh packaging/images/profiles/amd64-vm.env" docs/technical-mvp-handoff.md
require_line "print-image-validation-record-template.sh rpi4-arm64" docs/technical-mvp-handoff.md
require_line "Check each completed validation record" docs/technical-mvp-handoff.md
require_line "check-release-evidence-bundle.sh" docs/technical-mvp-handoff.md
require_line "/usr/lib/obos/mvp-runtime-readiness.sh summary" docs/technical-mvp-handoff.md
require_line "format=obos-release-evidence-bundle-check-v1" scripts/images/check-release-evidence-bundle.sh
require_line "release-notes.md" scripts/images/check-release-evidence-bundle.sh
require_line "validation-amd64-vm.record" scripts/images/check-release-evidence-bundle.sh
require_line "validation-rpi4-arm64.record" scripts/images/check-release-evidence-bundle.sh
require_line "obos-release.manifest.minisig" scripts/images/check-release-evidence-bundle.sh
require_line "obos-release.minisign.pub" scripts/images/check-release-evidence-bundle.sh
require_line "release notes minisign_public_key does not match" scripts/images/check-release-evidence-bundle.sh
require_line "tls_leaf_renewal_plan_result" scripts/images/check-release-evidence-bundle.sh
require_line "compose_image_pinning" scripts/images/check-release-evidence-bundle.sh
require_line "require_notes_value" scripts/images/check-release-evidence-bundle.sh
require_line "check-release-evidence-bundle.sh dist/images" docs/release-notes-template.md
require_line "minisign_public_key_fingerprint" docs/release-notes-template.md
require_line "tls_leaf_renewal_plan_result=PASS|FAIL" docs/release-notes-template.md
require_line "compose_image_pinning=PASS|FAIL|not_run" docs/release-notes-template.md
require_line "network_installer_used=yes|no" docs/release-notes-template.md
require_line "raw unencrypted backups are offered for web download or migration" docs/release-notes-template.md

require_line 'data-mutation-action="start"' apps/obos-web/index.html
require_line 'data-mutation-action="stop"' apps/obos-web/index.html
require_line 'data-mutation-action="restart"' apps/obos-web/index.html
require_line 'data-mutation-action="update"' apps/obos-web/index.html
require_line 'data-mutation-action="backup"' apps/obos-web/index.html
require_line 'data-mutation-action="portable-export"' apps/obos-web/index.html
require_line 'data-portable-download' apps/obos-web/index.html
require_line 'data-upload-portable' apps/obos-web/index.html
require_line 'data-mutation-action="portable-import-stage"' apps/obos-web/index.html
require_line 'data-mutation-action="restore-stage"' apps/obos-web/index.html
require_line 'data-agent-field="security-summary:result"' apps/obos-web/index.html
require_line 'data-agent-field="tls-summary:local_ca_sha256_fingerprint"' apps/obos-web/index.html
require_line 'data-agent-field="mqtt-summary:source_cidr"' apps/obos-web/index.html
require_line 'data-load-logs' apps/obos-web/index.html
require_line 'data-mutation-action="mqtt-enable-lan"' apps/obos-web/index.html
require_line 'data-mutation-action="mqtt-disable-lan"' apps/obos-web/index.html
require_line 'data-mutation-action="tls-generate"' apps/obos-web/index.html
require_line 'data-mutation-action="tls-export"' apps/obos-web/index.html
require_line 'data-mutation-action="set-hostname"' apps/obos-web/index.html
require_line 'data-mutation-action="set-timezone"' apps/obos-web/index.html

require_line "OBOS_IMAGE_PROFILE=amd64-vm" packaging/images/profiles/amd64-vm.env
require_line "OBOS_IMAGE_KIND=vm-image" packaging/images/profiles/amd64-vm.env
require_line "OBOS_OUTPUT_FORMAT=qcow2" packaging/images/profiles/amd64-vm.env
require_line "gnupg" packaging/images/profiles/amd64-vm.env
require_line "CHECK_AMD64_BUILD_HOST=" scripts/images/build-amd64-qcow2.sh
require_line "CHECK_QCOW2_MANIFEST=" scripts/images/build-amd64-qcow2.sh
require_line "run_build_host_preflight" scripts/images/build-amd64-qcow2.sh
require_line "REPO_STAGING_PARENT=" scripts/images/build-amd64-qcow2.sh
require_line "--exclude ./dist" scripts/images/build-amd64-qcow2.sh
require_file packaging/network/20-obos-dhcp.network
require_line "DHCP=yes" packaging/network/20-obos-dhcp.network
require_line "20-obos-dhcp.network" scripts/bootstrap/provision-debian.sh
require_line "systemctl enable systemd-networkd.service" scripts/bootstrap/provision-debian.sh
require_line "docker-cli" scripts/bootstrap/provision-debian.sh
require_line "docker.io" scripts/bootstrap/provision-debian.sh
# shellcheck disable=SC2016
require_line '--copy-in "${STAGED_REPO_DIR}:/opt/openbridgeos"' scripts/images/build-amd64-qcow2.sh
# shellcheck disable=SC2016
require_line 'OBOS_DISABLE_SSH=1 sh ${OBOS_PROVISION_SCRIPT}' scripts/images/build-amd64-qcow2.sh
# shellcheck disable=SC2016
require_line 'sh "${CHECK_QCOW2_MANIFEST}" "${MANIFEST}"' scripts/images/build-amd64-qcow2.sh
require_line "qcow2_contract:" scripts/images/print-image-build-plan.sh
require_line "OBOS_SMOKE_LOG_FILE" scripts/images/smoke-test-amd64-qcow2.sh
require_line "qemu exited before HTTPS health passed" scripts/images/smoke-test-amd64-qcow2.sh
require_line "OBOS_IMAGE_PROFILE=rpi4-arm64" packaging/images/profiles/rpi4-arm64.env
require_line "OBOS_IMAGE_KIND=rpi-image" packaging/images/profiles/rpi4-arm64.env
require_line "OBOS_OUTPUT_FORMAT=raw" packaging/images/profiles/rpi4-arm64.env
require_line "OBOS_OUTPUT_COMPRESSION=xz" packaging/images/profiles/rpi4-arm64.env
require_line "OBOS_IMAGE_EXTENSION=img.xz" packaging/images/profiles/rpi4-arm64.env
require_line "gnupg" packaging/images/profiles/rpi4-arm64.env
require_line "OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE=true" packaging/images/profiles/rpi4-arm64.env
require_line "CONFIG_BLK_DEV_NVME=y" packaging/images/profiles/rpi4-arm64.env
require_line "Raspberry Pi Network Installer" docs/image-build.md
require_line "rpi_contract:" scripts/images/print-image-build-plan.sh
require_line "profile with SSH enabled was accepted" scripts/checks/check-image-profiles.sh
require_line "Raspberry Pi profile without NVMe kernel config was accepted" scripts/checks/check-image-profiles.sh
require_line "Raspberry Pi firmware config is not a Linux kernel config" scripts/images/check-rpi-kernel-config.sh
require_line "CHECK_RPI_BOOT_FILES=" scripts/images/build-rpi4-arm64-image.sh
# shellcheck disable=SC2016
require_line 'OBOS_DISABLE_SSH=1 sh ${OBOS_PROVISION_SCRIPT}' scripts/images/build-rpi4-arm64-image.sh
# shellcheck disable=SC2016
require_line 'sh "${CHECK_RPI_BOOT_FILES}" "${BUILD_ROOT}"' scripts/images/build-rpi4-arm64-image.sh

require_line "sudo /usr/lib/obos/security-baseline.sh" README.md
require_line "nftables default-drop host firewall" README.md
require_line "SSH disabled by default" README.md
require_line "local CA per appliance instance" README.md

echo "mvp readiness: PASS"
