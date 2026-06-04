# Hardware Requirements

open bridge operating system targets small, reliable appliance hardware for local building automation workloads. The first supported hardware classes are Raspberry Pi 4+ and x86_64/amd64 systems.

## Raspberry Pi 4+

Recommended baseline:

- Raspberry Pi 4, Raspberry Pi 5, or newer compatible 64-bit Raspberry Pi board
- 4 GB RAM minimum, 8 GB recommended for larger histories, dashboards, or future local services
- official or high-quality USB-C power supply sized for the board and attached storage
- wired Ethernet for production installations
- SD, USB, or NVMe boot media supported by the board firmware
- 16 GB storage minimum, 32 GB or larger recommended
- reliable cooling for enclosed installations

Storage guidance:

- SD cards are acceptable for early tests and small installations.
- USB SSD or NVMe is recommended for long-running installations with history data.
- NVMe support is part of the Raspberry Pi image contract; `CONFIG_BLK_DEV_NVME=y` must stay enabled.
- Use application-level backups before replacing boot or data media.

Power guidance:

- Undervoltage can corrupt storage and cause hard-to-debug container failures.
- Avoid weak phone chargers and long, thin USB cables.
- Budget extra power for USB SSDs, NVMe adapters, radios, and attached gateways.

Network guidance:

- Ethernet is preferred for a fixed appliance.
- Wi-Fi can be evaluated later, but it is not the first release baseline.
- The default firewall exposes HTTPS only; MQTT LAN access remains explicit opt-in.

## x86_64 / amd64

Recommended baseline:

- 64-bit CPU with virtualization support for VM deployments
- 2 CPU cores minimum, 4 cores recommended for larger deployments
- 4 GB RAM minimum, 8 GB recommended
- 16 GB disk minimum, 32 GB or larger recommended
- SSD storage for production use
- wired Ethernet

Target environments:

- Proxmox
- Hyper-V
- VirtualBox
- bare-metal mini PCs
- other KVM/QEMU-capable hosts

The first VM artifact is planned as a Debian-based qcow2 image. ISO or installer media can follow after the qcow2 and Raspberry Pi image paths are repeatable.

## Sizing Notes

Resource needs depend primarily on:

- number of datapoints and adapters
- history retention and write volume
- Grafana, InfluxDB, TimescaleDB, or other optional services once added
- MQTT traffic volume
- backup frequency and retention

The first release should stay conservative: open bridge server and Mosquitto are the default managed services. Optional data services should be added through explicit appliance workflows later, not silently bundled into every image.

## Recovery Expectations

Appliance hardware should allow at least one practical recovery path:

- physical access to power-cycle the device
- removable or replaceable boot media
- console, HDMI, serial, or hypervisor console access for first recovery
- recent backup stored away from the appliance

SSH is disabled by default. Remote shell access must be enabled deliberately and reviewed together with the firewall policy.
