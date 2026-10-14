# Code- und Security-Review vom 14. Oktober 2026

## Ergebnis

Geprüfter Stand: `e0e405c8e34f4aca0a15bf2a8e9b74f80ecc8eba` (`main`).

- P1: keine bestätigten Befunde
- P2: vier bestätigte Befunde, alle im Arbeitsstand korrigiert
- P3: vier verbleibende Hardening-Empfehlungen ohne unmittelbare P1/P2-Auswirkung

Die Einstufung folgt dem operativen Risiko für eine Gebäudeautomations-Appliance:
P1 bedeutet unmittelbar ausnutzbare vollständige Kompromittierung bei realistischer
Angreiferposition; P2 bedeutet hohe Auswirkung oder hohe Ausnutzbarkeit mit einer
zusätzlichen Voraussetzung; P3 bezeichnet begrenzte Risiken und Defence-in-Depth.

## Umfang und Methode

Der Review umfasste die privilegierten Shell- und Python-Komponenten, HTTP- und
Onboarding-Authentisierung, Session- und CSRF-Grenzen, nginx/TLS, systemd/sudoers,
nftables, Container- und Compose-Konfiguration, Backup/Restore und portable
Importe, signierte Appliance-Updates, CI/Release-Workflows sowie Browser-Code.

Neben manueller Datenfluss- und Trust-Boundary-Analyse wurden alle vorhandenen
Checks, Python- und Shell-Syntaxprüfungen, strikte Compose-Digest-Prüfung sowie
neue Negativtests für Login-Bruteforce und manipulierte Archive ausgeführt.

## Korrigierte P2-Befunde

### P2-01: Unsichere privilegierte Archivextraktion

`restore-inspect` prüfte nur absolute Pfade und `..`. Ein formal vollständiges
Backup mit einem Symlink wurde akzeptiert. Portable Importe und Restore-Staging
extrahierten danach als root. Links, Spezialdateien, doppelte Member und stark
expandierende Archive konnten dadurch die Annahmen der nachfolgenden Prüfung
verletzen und je nach Archivinhalt Hostpfade, Ressourcen oder Restore-Ziele
beeinflussen.

Korrektur:

- zentrale, robuste Member-Prüfung mit Pythons `tarfile` vor jeder Extraktion
- nur reguläre Dateien und Verzeichnisse; keine Symlinks, Hardlinks oder Devices
- keine absoluten, relativen, doppelten oder unerwarteten Member
- maximal 100.000 Member und standardmässig 10 GiB expandierte Nutzdaten
- Extraktion zusätzlich mit `--no-same-owner --no-same-permissions`
- Regressionstest `scripts/checks/check-archive-safety.sh`

### P2-02: Unbegrenzte Online-Passwortversuche

Der HTTPS-Login erlaubte beliebig viele Versuche gegen den einzigen
Administratoraccount. Der gespeicherte SHA-512-crypt-Hash und ein schwaches,
aber formal gültiges Passwort machten einen Online-Angriff aus dem LAN
unnötig günstig.

Korrektur:

- pro verifiziertem Client-IP-Bucket höchstens fünf Fehlversuche in fünf Minuten
- anschliessend fünf Minuten Lockout mit HTTP `429` und `Retry-After`
- erfolgreiche Anmeldung löscht nur den eigenen Fehlversuchsstatus
- nginx setzt die verwendete Forwarded-Adresse selbst; direkte Header-Spoofs von
  Remote-Clients erreichen den loopbackgebundenen Dienst nicht
- Regressionstests für Lockout, korrekte Passwörter im Lockout und getrennte IPs

### P2-03: Übernahme des uninitialisierten Geräts im Setup-LAN

Während des fünfminütigen Onboarding-Fensters konnte jeder erreichbare LAN-Client
das erste Administratorpasswort setzen. Die kurze Zeitspanne reduzierte die
Wahrscheinlichkeit, stellte aber keinen Besitznachweis für das konkrete Gerät dar.

Korrektur:

- kryptografisch zufälliger, einmaliger Setup-Token pro Appliance
- Token wird nur lokal beziehungsweise in `OBOS-ONBOARDING.txt` auf der
  bootzugänglichen Partition bereitgestellt, nicht über die unauthentisierte API
- konstante Token-Prüfung vor dem Setzen des ersten Passworts
- Token wird nach erfolgreichem Onboarding aus dem Appliance-State gelöscht
- UI- und API-Negativtest für falsche Tokens

Spätere Produktentscheidung: Diese Korrektur wird ab `2026.10.6-rc.3` bewusst
zurückgenommen, weil eine Konsolen- oder Bootmedieninteraktion für die
Zielgruppe nicht praktikabel ist. Das Onboarding funktioniert seither rein im
Browser innerhalb eines fünfminütigen Fensters pro Boot. Damit besteht erneut
ein First-Client-wins-Risiko im lokalen Netz; uninitialisierte Appliances dürfen
daher nur in einem vertrauenswürdigen Einrichtungsnetz betrieben werden.

### P2-04: Veränderliche Supply-Chain-Referenzen

Die Produktions-Compose-Datei referenzierte `eclipse-mosquitto:2` und
`openbridgeserver:latest`; die CI verwendete `actions/checkout@v7`. Ein später
veränderter Tag hätte somit ohne Quelländerung anderen Code in Build oder Betrieb
bringen können.

Korrektur:

- beide Multi-Arch-Container-Images auf verifizierte Manifest-Digests fixiert
- `actions/checkout` auf Commit `3d3c42e5aac5ba805825da76410c181273ba90b1`
  (v7) fixiert
- strikte Digest-Prüfung ist Bestandteil der Verifikation

## P3 / Defence-in-Depth

1. Die Passwortablage verwendet SHA-512 crypt. Der Online-Angriffsweg ist jetzt
   begrenzt; mittelfristig sollte auf Argon2id oder scrypt mit transparenter
   Migration beim Login umgestellt werden.
2. Die Container laufen ohne User-Namespace-Remapping. `no-new-privileges`,
   begrenzte PIDs, lokale Port-Bindings und schmale Volumes reduzieren das Risiko;
   Rootless Docker oder User-Namespaces bleiben eine spätere Härtungsstufe.
3. OpenBridgeServer speichert Browser-Tokens im `localStorage`. Diese Korrektur
   gehört in das separate OpenBridgeServer-Upstream-Projekt; OBOS begrenzt das
   Risiko inzwischen mit einer restriktiven CSP für seine eigenen `/obos`-Seiten.
4. Ein globaler `Permissions-Policy`-Header bleibt zurückgestellt, bis die
   benötigten OpenBridgeServer-Browserfunktionen inventarisiert und im Zielsystem
   getestet sind.

Bereits umgesetzte P3-Härtungen aus dem externen Penetrationstest:

- HSTS für sämtliche HTTPS-Antworten
- restriktive, auf `/obos` begrenzte Content-Security-Policy ohne Kompatibilitätsrisiko
  für die separat ausgelieferte OpenBridgeServer-Oberfläche
- ausschließlich moderne AEAD-Cipher für TLS 1.2; TLS 1.3 bleibt unverändert aktiv
- privater Unix-Socket zwischen nginx und Agent-Bridge statt eines TCP-Listeners

## Verifikation

Erforderliche Nachweise:

```text
python3 -m py_compile scripts/agent/obos-agent-http.py
sh -n scripts/obosctl
sh scripts/checks/check-archive-safety.sh
sh scripts/checks/check-obos-agent-http.sh
OBOS_REQUIRE_PINNED_IMAGES=1 sh scripts/images/check-compose-image-pinning.sh apps/openbridgeserver/compose.yaml
for f in scripts/checks/*.sh; do sh "$f"; done
```

Alle aufgeführten Nachweise sowie sämtliche Skripte unter `scripts/checks/`
bestanden gegen den vollständigen geänderten Stand. ShellCheck 0.11.0 meldete
für alle produktiven und Test-Shellskripte keine Befunde; `git diff --check` und
die Suche nach typischen eingecheckten Secret-Mustern waren ebenfalls sauber.
