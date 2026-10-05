# CUPS Druck- & Scanserver (Brother MFC-260C)

[![Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FZocker1012%2Fha-cups-addon%2Fmain%2Fcups-brother-mfc260c%2Fconfig.yaml&query=%24.version&label=Version)](cups-brother-mfc260c/CHANGELOG.md)
![Architektur](https://img.shields.io/badge/arch-amd64-blue)
[![Build](https://github.com/Zocker1012/ha-cups-addon/actions/workflows/build.yaml/badge.svg)](https://github.com/Zocker1012/ha-cups-addon/actions/workflows/build.yaml)
[![Prüfung](https://github.com/Zocker1012/ha-cups-addon/actions/workflows/lint.yaml/badge.svg)](https://github.com/Zocker1012/ha-cups-addon/actions/workflows/lint.yaml)

Home-Assistant-Add-on-Repository für den per USB angeschlossenen
**Brother MFC-260C**: Drucken und Scannen im ganzen Heimnetz, ohne Treiber auf
deinen Geräten. Basiert auf CUPS / Legacy Printer Application (OpenPrinting),
AirSane und SANE.

## Funktionen

- **Drucken** per AirPrint / IPP Everywhere (Legacy Printer Application im
  CUPS-3-Stil, klassisches CUPS als Rückfallebene)
- **Scannen** per AirScan / eSCL – Windows, macOS, Android, Linux und Browser
- **Scan-Menü am Gerät** (Datei, Bild, Text, E-Mail) speichert direkt in einen
  Ordner, auf Wunsch mit Texterkennung
- **Druckordner**: Datei hineinlegen, sie wird gedruckt
- Weboberfläche in der HA-Seitenleiste, Anmeldung mit HA-Konten

## Installation

[![Repository zu Home Assistant hinzufügen](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FZocker1012%2Fha-cups-addon)

Oder von Hand: Einstellungen → Add-ons → Add-on-Store → ⋮ → **Repositories** →
`https://github.com/Zocker1012/ha-cups-addon` hinzufügen. Danach
**CUPS Druck- & Scanserver (Brother MFC-260C)** installieren, Drucker per USB anschließen und
das Add-on starten – der Drucker wird automatisch eingerichtet.

Einrichtung, Einstellungen und Fehlersuche: [Dokumentation](cups-brother-mfc260c/DOCS.md).

## Aufbau

| Pfad | Inhalt |
|---|---|
| [`cups-brother-mfc260c/`](cups-brother-mfc260c/) | das Add-on: Dockerfile, Skripte (`rootfs/`), Einstellungen, Übersetzungen |
| [`cups-brother-mfc260c/drivers/`](cups-brother-mfc260c/drivers/) | Brother-Treiber (unverändert) mit Lizenzen und GPL-Quellcode |
| [`cups-brother-mfc260c/patches/`](cups-brother-mfc260c/patches/) | Anpassungen an AirSane |
| [`.github/workflows/`](.github/workflows/) | `build.yaml` baut das fertige Image nach `ghcr.io`, `lint.yaml` prüft jede Änderung |

## Lizenz

Copyright (C) 2026 Zocker1012

Der eigene Code dieses Repositorys (Skripte, Dockerfile, Workflows,
Startseite, Symbol, Doku) steht unter der
[GNU General Public License Version 3](LICENSE) oder, nach deiner Wahl, einer
späteren Version. Du darfst ihn nutzen, verändern und weitergeben, auch als
Fork – musst dabei aber den Urheber nennen und Änderungen ebenfalls unter der
GPL offenlegen.

Ausgenommen sind Bestandteile anderer mit eigener Lizenz:

- **Brother-Treiber** in `cups-brother-mfc260c/drivers/`: teils GPL-2.0, teils
  Brothers eigene Lizenz, beide erlauben die Weitergabe.
  - [`drivers/LICENSE-Brother.txt`](cups-brother-mfc260c/drivers/LICENSE-Brother.txt)
    – Lizenz je Paket, Brothers Lizenztexte und was das Add-on anpasst
  - [`drivers/LICENSE-GPL-2.0.txt`](cups-brother-mfc260c/drivers/LICENSE-GPL-2.0.txt)
    – GNU GPL Version 2
  - [`drivers/source/`](cups-brother-mfc260c/drivers/source/) – Brothers
    Quellcode der GPL-Teile

  Beide Lizenzdateien sind auch im Image enthalten
  (`/usr/share/doc/brother-drivers/`).
- **AirSane-Patches** in `cups-brother-mfc260c/patches/`: GPL-3.0 wie AirSane.

Die übrigen Programme im Image (CUPS, AirSane, Tesseract …) und ihre Lizenzen
nennt die Dokumentation unter „Für Entwickler“.

## Marken

CUPS ist eine Marke von Apple Inc., AirPrint von Apple Inc., Brother und
MFC-260C von Brother Industries, Ltd. Die Namen stehen hier nur, um zu
beschreiben, worauf das Add-on aufbaut und mit welchem Gerät es funktioniert.
Privates Projekt, weder von OpenPrinting, Apple noch Brother unterstützt.
