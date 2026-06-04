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
- einer Weboberfläche für die Appliance-Administration

Siehe [docs/architecture.md](docs/architecture.md),
[docs/security.md](docs/security.md),
[docs/hardening.md](docs/hardening.md) und
[docs/decisions/0001-target-debian-trixie.md](docs/decisions/0001-target-debian-trixie.md).

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

## Security Baseline

Nach Provisionierung und Neustart wird die Appliance so validiert:

```sh
sudo /usr/lib/obos/security-baseline.sh
```

Siehe [docs/security-baseline-testplan.md](docs/security-baseline-testplan.md).

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
