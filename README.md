# CUPS Addon (Brother MFC-260C)

Home-Assistant-Add-on, das einen per USB angeschlossenen **Brother MFC-260C**
ins Netzwerk bringt – ohne Treiber auf deinen Geräten:

- **Drucken** per AirPrint / IPP Everywhere (Legacy Printer Application im
  CUPS-3-Stil, klassisches CUPS als Rückfallebene)
- **Scannen** per AirScan / eSCL (Windows, macOS, Android, Linux, Browser)
- **Scan-Menü am Gerät** (Datei, Bild, Text, E-Mail) speichert direkt in einen
  Ordner, auf Wunsch mit Texterkennung
- **Druckordner**: Dateien hineinlegen, sie werden gedruckt
- Weboberfläche in der HA-Seitenleiste, Anmeldung mit HA-Konten

## Installation

1. In Home Assistant: Einstellungen → Add-ons → Add-on-Store → ⋮ →
   **Repositories** → `https://github.com/Zocker1012/ha-cups-addon` hinzufügen.
2. **CUPS Addon (Brother MFC-260C)** installieren und starten. Der Drucker
   wird automatisch eingerichtet.

Nur für amd64. Alle Details stehen in der
[Dokumentation](cups-brother-mfc260c/DOCS.md), Änderungen im
[Changelog](cups-brother-mfc260c/CHANGELOG.md).

## Aufbau

| Pfad | Inhalt |
|---|---|
| `cups-brother-mfc260c/` | das Add-on (Dockerfile, Skripte in `rootfs/`, Einstellungen) |
| `cups-brother-mfc260c/drivers/` | Brother-Treiber, unverändert, mit Lizenzen und GPL-Quellcode |
| `cups-brother-mfc260c/patches/` | Anpassungen an AirSane |
| `.github/workflows/build.yaml` | baut das fertige Image nach `ghcr.io` |

## Lizenzen

Die Brother-Treiber stehen teils unter der GPL-2.0, teils unter Brothers
eigener Lizenz; beide erlauben die Weitergabe. Die Lizenztexte liegen bei den
Treibern:

- [`drivers/LICENSE-Brother.txt`](cups-brother-mfc260c/drivers/LICENSE-Brother.txt)
  – Lizenz je Paket, Brothers Lizenztexte und was das Add-on anpasst
- [`drivers/LICENSE-GPL-2.0.txt`](cups-brother-mfc260c/drivers/LICENSE-GPL-2.0.txt)
  – GNU GPL Version 2
- [`drivers/source/`](cups-brother-mfc260c/drivers/source/) – Brothers
  Quellcode der GPL-Teile

Beide Lizenzdateien sind auch im Image enthalten
(`/usr/share/doc/brother-drivers/`). Die übrigen Bestandteile (CUPS, AirSane,
Tesseract …) und ihre Lizenzen stehen in der Dokumentation unter „Für
Entwickler“. Privates Projekt, nicht mit Brother verbunden.
