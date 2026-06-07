#!/usr/bin/env sh
set -eu

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CHECKER="scripts/images/validate-image-profiles.sh"

fail() {
  echo "image profile fixture failed: $1" >&2
  exit 1
}

replace_line() {
  key="$1"
  value="$2"
  file="$3"
  awk -v key="${key}" -v value="${value}" '
    BEGIN { replaced = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print key "=" value
      }
    }
  ' "${file}" > "${file}.tmp"
  mv "${file}.tmp" "${file}"
}

sh "${CHECKER}" packaging/images/profiles/amd64-vm.env packaging/images/profiles/rpi4-arm64.env >/dev/null

bad_ssh_profile="${TMP_DIR}/bad-ssh.env"
cp packaging/images/profiles/amd64-vm.env "${bad_ssh_profile}"
replace_line OBOS_IMAGE_DEFAULT_SSH enabled "${bad_ssh_profile}"
if sh "${CHECKER}" "${bad_ssh_profile}" >/dev/null 2>&1; then
  fail "profile with SSH enabled was accepted"
fi

bad_provisioner_profile="${TMP_DIR}/bad-provisioner.env"
cp packaging/images/profiles/amd64-vm.env "${bad_provisioner_profile}"
replace_line OBOS_PROVISION_SCRIPT scripts/bootstrap/other.sh "${bad_provisioner_profile}"
if sh "${CHECKER}" "${bad_provisioner_profile}" >/dev/null 2>&1; then
  fail "profile with wrong provisioner was accepted"
fi

bad_rpi_nvme_profile="${TMP_DIR}/bad-rpi-nvme.env"
cp packaging/images/profiles/rpi4-arm64.env "${bad_rpi_nvme_profile}"
replace_line OBOS_KERNEL_REQUIRED_CONFIG 'CONFIG_PCIE_BRCMSTB=y,CONFIG_USB_XHCI_PCI=y' "${bad_rpi_nvme_profile}"
if sh "${CHECKER}" "${bad_rpi_nvme_profile}" >/dev/null 2>&1; then
  fail "Raspberry Pi profile without NVMe kernel config was accepted"
fi

bad_rpi_network_installer_profile="${TMP_DIR}/bad-rpi-network-installer.env"
cp packaging/images/profiles/rpi4-arm64.env "${bad_rpi_network_installer_profile}"
replace_line OBOS_RPI_NETWORK_INSTALLER_COMPATIBLE false "${bad_rpi_network_installer_profile}"
if sh "${CHECKER}" "${bad_rpi_network_installer_profile}" >/dev/null 2>&1; then
  fail "Raspberry Pi profile without Network Installer compatibility was accepted"
fi

echo "image profile fixture: PASS"
