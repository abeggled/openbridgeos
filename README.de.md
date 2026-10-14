# open bridge operating system

Sprachen: [English](README.md) | [Deutsch](README.de.md)

open bridge operating system (obos) ist eine sicherheitsorientierte Debian-Appliance
zum Betrieb von open bridge server mit möglichst wenig Einrichtungsaufwand.

Die Zielgruppe soll ein Image auf einen USB-Stick oder eine SD-Karte schreiben,
es auf einem Raspberry Pi 4+ oder x86_64-System booten, einen Browser öffnen
und eine einsatzbereite open bridge server Installation bedienen können, ohne
Linux-Pakete, Docker-Images, Compose-Dateien, Volumes oder Update-Abläufe
manuell verwalten zu müssen.

## Umfang

obos ist bewusst keine zweite Gebäudeautomationsoberfläche. open bridge server
bleibt zuständig für Adapter, Datenpunkte, Bindings, Logik, Visualisierung,
Benutzer, API-Schlüssel und MQTT-Zugriff.

obos verwaltet die Appliance-Ebene:

- Einrichtung beim ersten Start
- Host-Identität, Netzwerk, Zeitzone und Systemzugang
- Lebenszyklus von open bridge server
- Updates der Container-Laufzeitumgebung
- Systemupdates
- Health Checks und Logs
- Backup- und Restore-Orchestrierung
- Host-Hardening
- Image-Builds für Raspberry Pi und x86_64

## Initiale Architektur

Version 0.1 ist geplant mit:

- minimalem Debian-13-Trixie-Basissystem
- Docker Engine mit Compose v2 aus Debian-Paketen
- nginx TLS Reverse Proxy auf TCP `443`
- nftables Host-Firewall mit Default-Drop
- sysctl Hardening-Baseline
- standardmässig deaktiviertem SSH, wenn vorhanden
- open bridge server und Mosquitto als primär verwalteter App
- persistenten Anwendungsdaten unter `/srv/obos`
- einem kleinen lokalen `obos-agent`-Dienst
- einer mit Basic Auth geschützten Weboberfläche für die Appliance-Administration

Siehe [docs/architecture.md](docs/architecture.md),
[docs/security.md](docs/security.md),
[docs/hardening.md](docs/hardening.md) und
[docs/decisions/0001-target-debian-trixie.md](docs/decisions/0001-target-debian-trixie.md).

## Release-Image installieren

Das passende Artefakt und die zugehörige `.sha256`-Datei unter
[GitHub Releases](https://github.com/abeggled/openbridgeos/releases)
herunterladen. Vor der Verwendung die Ausgabe von `sha256sum <Artefakt>` mit
dem Hash in der heruntergeladenen Prüfsummendatei vergleichen. Bei der
ISO-Installation und beim Raspberry-Pi-Image wird das gewählte Zielmedium
gelöscht; deshalb das Ziel sorgfältig prüfen.

### x86_64-Hardware: Installer-ISO

Für einen Mini-PC oder ein anderes dediziertes amd64-System wird
`obos-amd64-installer-<Version>.iso` verwendet:

1. Die ISO als Image auf einen USB-Stick schreiben; die ISO-Datei nicht bloss
   auf den Stick kopieren. Das Zielsystem von diesem Stick starten, vorzugsweise
   im UEFI-Modus.
2. Fünf Sekunden warten. **`Start installer`** startet automatisch; nur für
   die erweiterten manuellen oder Rettungsoptionen während des Countdowns eine
   Taste drücken.
3. Ist genau eine geeignete interne Platte mit mindestens 8 GiB vorhanden,
   Gerätename, Modell und Grösse in der einmaligen Löschwarnung prüfen und
   bestätigen. OBOS partitioniert danach die gesamte Platte und installiert
   GRUB für BIOS oder UEFI automatisch. Bei mehreren geeigneten Platten wählt
   der Installer niemals selbst: die übrigen Platten trennen oder über
   **Advanced install options** die Zielplatte ausdrücklich auswählen.
4. Nach dieser Bestätigung sind keine Eingaben für Debian-Benutzer, Passwort,
   NTP, Partitionierung oder GRUB-Ziel erforderlich. Der Installer
   synchronisiert die Zeit über `pool.ntp.org`.
5. Das individuelle Recovery-Passwort des Benutzers `obos` sowie die auf dem
   Abschlussbildschirm angezeigte DHCP-IPv4-Adresse und Web-Console-URL
   notieren. Den USB-Stick entfernen und von der installierten Platte neu
   starten.

Jede Installation erzeugt unterschiedliche Passwörter für die Linux-Benutzer
`root` und `obos`. Diese sind vom OBOS-Webbenutzer `admin` getrennt. Nach dem
Web-Onboarding können beide Recovery-Passwörter unter **System Diagnostics →
System Credentials** nach erneuter Eingabe des aktuellen Web-Admin-Passworts
angezeigt oder rotiert werden. Jede Anzeige und Rotation wird ohne die
Passwortwerte protokolliert.

### x86_64-VM: QCOW2

Für Proxmox oder einen anderen QEMU/KVM-kompatiblen Hypervisor wird
`obos-amd64-vm-<Version>.qcow2` verwendet:

1. Eine VM mit UEFI-Firmware, mindestens 2 CPU-Kernen, 4 GB RAM, einem
   gebridgten Netzwerkadapter mit DHCP und ohne Installer-ISO erstellen.
2. Die QCOW2-Datei als vorhandene Systemplatte importieren, als VirtIO/SCSI
   einbinden und als erstes Boot-Gerät konfigurieren. Mindestens 16 GB, für den
   Produktivbetrieb besser 32 GB, zuweisen.
3. Die VM starten. Es gibt kein Installer-Menü; die vorbereitete Platte startet
   direkt und führt die First-Boot-Provisionierung aus.

### Raspberry Pi 4+: ARM64-Image

Für einen Raspberry Pi 4, Pi 5 oder ein neueres kompatibles 64-Bit-Board wird
`obos-rpi4-arm64-<Version>.img.xz` verwendet:

1. Im Raspberry Pi Imager **Use custom** wählen, die komprimierte `.img.xz`-
   Datei auswählen und auf die vorgesehene SD-Karte, USB-SSD oder das
   NVMe-Laufwerk schreiben. Alternativ kann Balena Etcher verwendet werden.
2. Das Medium einsetzen, kabelgebundenes Ethernet anschliessen und den
   Raspberry Pi einschalten. Es gibt kein Installer-Menü; das Image startet
   direkt und führt die First-Boot-Provisionierung aus.

### Erste Web-Einrichtung

Nach dem ersten Start einige Minuten für die Provisionierung warten. Die
DHCP-Adresse im Router oder Hypervisor ermitteln und
`https://<Geräte-IP>/obos/onboarding/` öffnen. Eine Zertifikatswarnung ist zu
erwarten, bis die gerätespezifische OBOS-CA als vertrauenswürdig hinterlegt
wurde. Das Passwort für den Webbenutzer `admin` direkt im Browser festlegen
(mindestens 12 Zeichen); eine Konsolenanmeldung oder ein Setup-Token ist nicht
erforderlich. Die Appliance bis zum Abschluss dieses Schritts nur in einem
vertrauenswürdigen Einrichtungsnetz betreiben. Ist das fünfminütige
Onboarding-Fenster abgelaufen, öffnet ein Neustart der Appliance ein neues
Fenster.

## Entwicklungsinstallation

Der erste Entwicklungspfad zielt auf einen frischen Debian-13-Host:

```sh
sudo scripts/bootstrap/provision-debian.sh
sudo reboot
```

Bei Entwicklungsinstallationen über SSH zuerst [docs/install-debian.md](docs/install-debian.md)
lesen. Die Standard-Hardening-Policy deaktiviert SSH, wenn der Dienst vorhanden ist.

Siehe [docs/install-debian.md](docs/install-debian.md) und
[docs/image-build.md](docs/image-build.md).

## Hardware

Siehe [docs/hardware.md](docs/hardware.md) für Raspberry-Pi-4+- und x86_64-Hinweise
zu Dimensionierung, Speicher, Stromversorgung und Recovery.

## Security Baseline

Nach Provisionierung und Neustart wird die Appliance so validiert:

```sh
sudo /usr/lib/obos/security-baseline.sh
sudo /usr/lib/obos/mvp-runtime-readiness.sh
```

Siehe [docs/security-baseline-testplan.md](docs/security-baseline-testplan.md).

Die Weboberfläche und die `/obos/api/` Bridge sind durch eine serverseitige
GUI-Session geschützt. Beim ersten Boot setzt die Administration das initiale
Passwort in einem reinen Browser-Onboarding. Dieses ist bis zum Setzen des
ersten Passworts während fünf Minuten pro Boot verfügbar; die Ersteinrichtung
muss deshalb in einem vertrauenswürdigen lokalen Netz stattfinden.

## TLS Trust

Das geplante Release-TLS-Modell verwendet eine lokale CA pro Appliance-Instanz.
Die ersten Hilfsprogramme können bereits Trust-Material erzeugen, Fingerprints
ausgeben und ein öffentliches Trust-Bundle exportieren:

```sh
sudo obosctl tls-generate
sudo obosctl tls-info
sudo obosctl tls-export
```

open bridge server wird über den lokalen TLS Reverse Proxy auf TCP `443`
bereitgestellt. Der direkte OBS-HTTP-Port bindet nur an `127.0.0.1:8080`.

Siehe [docs/tls-trust.md](docs/tls-trust.md).

## Administration

Die erste Appliance-Administrationsschnittstelle ist `obosctl`:

```sh
obosctl status
sudo obosctl backup
sudo obosctl update
```

Siehe [docs/admin-cli.md](docs/admin-cli.md).

## Repository-Struktur

```text
apps/
  openbridgeserver/        Verwaltete App-Definition für open bridge server
docs/
  admin-cli.md             Lokale Appliance-Administrationsbefehle
  architecture.md          Systemform und Designentscheidungen
  decisions/               Architecture Decision Records
  hardening.md             Host-Firewall, SSH und sysctl-Hardening
  hardware.md              Hardware-Dimensionierung, Speicher und Stromversorgung
  install-debian.md        Erster Debian-Entwicklungsinstallationspfad
  image-build.md           Bootfähiges Image-Profil und Build-Plan
  security-baseline-testplan.md  Erster Security-Validierungsplan für VMs
  security.md              Security-Modell und Hardening-Prinzipien
  tls-trust.md             Notizen zum lokalen CA-Trust-Material
  roadmap.md               MVP-Phasen
packaging/
  apt/                     Debian-Richtlinie für unbeaufsichtigte Security-Updates
  docker/                  Docker-Daemon-Defaults
  images/                  Profile für bootfähige Images
  nginx/                   TLS Reverse Proxy Konfiguration
  nftables/                Host-Firewall-Regeln
  sysctl/                  Kernel- und Netzwerk-Hardening des Hosts
  systemd/                 Host-Dienste und Timer
scripts/
  audit/                   Audit-Skripte für Zielsysteme
  bootstrap/               First-Boot- und Host-Provisioning-Skripte
  checks/                  CI-Validierungshelfer
  hardening/               Host-Hardening-Helfer
  images/                  Validierung und Build-Plan-Helfer für Image-Profile
  tls/                     TLS-Trust-Hilfsskripte
```

## Sicherheit

Security ist Teil der Produktoberfläche, kein optionaler Hardening-Schritt.
Siehe [SECURITY.md](SECURITY.md) für Meldewege und [docs/security.md](docs/security.md)
für das initiale Appliance-Security-Modell.

## Status

Früher Projektaufbau. Der erste Meilenstein ist ein bootfähiges Debian-basiertes
Image, das open bridge server zuverlässig startet und eine kleine lokale
Administrationsoberfläche für Appliance-Operationen bereitstellt.
