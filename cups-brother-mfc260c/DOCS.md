# CUPS Addon (Brother MFC-260C)

Druck- und Scanserver für deinen per USB angeschlossenen **Brother MFC-260C**.
Du druckst per **AirPrint / IPP Everywhere** und scannst per **AirScan / eSCL**
– ohne Treiber auf deinen Geräten.

## Einrichtung

1. Schließ den Drucker per USB an deinen Home-Assistant-Rechner an und schalte
   ihn ein.
2. Starte das Add-on. Es legt den Drucker automatisch als **MFC260C** an
   (Papier A4) – auch wenn du ihn erst später einschaltest.

Danach finden deine Geräte Drucker und Scanner im Netzwerk von selbst:

| Gerät | Drucken | Scannen |
|---|---|---|
| Windows 10/11 | Einstellungen → Drucker & Scanner → Gerät hinzufügen (Treiber „Microsoft IPP Class Driver“ ist richtig) | ebenso, App „Windows-Scan“ |
| Android | direkt im Druckdialog | App „Mopria Scan“ |
| iPhone/iPad | direkt im Druckdialog | nur mit eSCL-fähiger App |
| macOS | Systemeinstellungen → Drucker & Scanner | Vorschau → Ablage → Von Scanner importieren |
| Linux | automatisch | Simple Scan (`sane-airscan`) |
| Browser | – | HA-Seitenleiste → Scanner |

## Weboberfläche und Anmeldung

Die Verwaltung öffnest du über die **HA-Seitenleiste** (dort bist du
automatisch angemeldet) oder direkt unter `http://<IP-von-HA>:631/`. Die
Admin-Seiten nutzen dort ein selbst signiertes Zertifikat, die Warnung im
Browser kannst du also ignorieren.

Wer sich direkt anmelden darf, legst du unter **Anmeldung → Art** fest:

| Art | Modus `printer_app` | Modus `cups` |
|---|---|---|
| `homeassistant` (Standard) | nur über die HA-Seitenleiste | mit jedem HA-Benutzerkonto |
| `manual` | mit dem Passwort | mit Benutzername (Standard `print`) und Passwort |

Lässt du bei `manual` das Passwort leer, erzeugt das Add-on eins und schreibt
es ins Log. Zum Drucken braucht niemand eine Anmeldung.

Die Brother-Optionen (Qualität, Medientyp, Graustufen …) findest du in der
Weboberfläche unter **Printing Defaults**, das Papierformat unter **Media**.

## Scanner

- **Glas oder Einzug** wählt der MFC-260C selbst: Liegt Papier im Einzug (das
  Display zeigt einen blinkenden Strich), scannt er von dort, sonst vom Glas.
  Für mehrere Seiten wählst du im Programm „Feeder“/Einzug und PDF, sonst
  kommt nur die erste Seite.
- **Auflösung:** Das Gerät schafft optisch 600 dpi (Standardgrenze). 1200 dpi
  sind hochgerechnet und sehr langsam. Mehr bietet das Add-on nicht an, weil
  solche Scans scheitern.

### Scan-Menü am Gerät

Schaltest du **Scan-Menü am Gerät → Scan-Menü nutzen** ein, speichert das Menü
**Scan** am MFC-260C direkt in deinen Scan-Ordner (Standard `/share/scans`,
per Samba unter „share“ erreichbar). Das Gerät meldet nur den gewählten
Menüpunkt, alles andere stellst du im Add-on ein:

| Menüpunkt | Format | Farbe |
|---|---|---|
| Datei, OCR, E-Mail | Einstellung „Format“ | Einstellung „Farbe“ |
| Bild | immer JPEG | Einstellung „Farbe bei Bild“ |

Die Auflösung gilt für alle Menüpunkte.

Mehrere Seiten aus dem Einzug landen als PDF in einer Datei, als JPEG/PNG in
einer Datei pro Seite. Nach jedem Scan sendet das Add-on das Ereignis
`cups_addon_scan` (`status`, `file`, `target`) an Home Assistant, z. B. für
eine Benachrichtigung:

```yaml
triggers:
  - trigger: event
    event_type: cups_addon_scan
    event_data:
      status: ok
actions:
  - action: notify.notify
    data:
      message: "Neuer Scan: {{ trigger.event.data.file }}"
```

## Druckordner

Schaltest du **Druckordner → Druckordner nutzen** ein, wird jede Datei
gedruckt, die du in den Ordner legst (Standard `/share/print`, z. B. per Samba
oder aus einer Automation). Möglich sind PDF, PostScript, JPEG und PNG.
Papierformat (Standard A4), Farbe und Qualität stellst du im Add-on ein.
Danach liegt die Datei in `gedruckt/` bzw. `fehler/`.

## Druckerstatus in Home Assistant

Die **IPP-Integration** findet den Drucker automatisch (Einstellungen →
Geräte & Dienste) und zeigt seinen Status. Tintenstände meldet der
Brother-Treiber nicht.

## Einstellungen

So sehen die Gruppen in der YAML-Ansicht aus:

```yaml
printer:
  mode: printer_app       # printer_app | cups
  auto_setup: true
login:
  method: homeassistant   # homeassistant | manual
  username: print         # optional, nur manual + Modus cups
  password: geheim        # optional, nur manual
scanning:
  enabled: true
  max_resolution: "600"   # 600 | 1200
scan_menu:
  enabled: false
  folder: /share/scans    # unter /share oder /media
  format: pdf             # pdf | jpeg | png
  resolution: "300"       # 100 | 150 | 200 | 300 | 600
  color: color            # color | gray
  image_color: color      # color | gray (Menüpunkt "Bild")
folder_printing:
  enabled: false
  path: /share/print      # unter /share oder /media
  paper: a4               # a4 | a5 | a6 | letter | legal |
                          # photo_10x15 | photo_13x18 | photo_9x13
  color: color            # color | gray
  quality: normal         # draft | normal | fine
log_level: info           # debug | info | warning | error
```

**Modus:** `printer_app` ist der CUPS-3-Weg (Legacy Printer Application von
OpenPrinting) und der Normalfall. `cups` ist der klassische CUPS-Server als
Rückfallebene. Dort legst du den Drucker einmal selbst an (Administration →
Add Printer → Brother MFC-260C, „Share This Printer“). Beide laufen auf Port
631.

## Fehlersuche

- **Drucker wird nicht gefunden:** Ist er eingeschaltet und per USB verbunden?
  Hast du ihn gelöscht, starte das Add-on einmal neu.
- **Druck oder Scan klappt nicht:** Setz **Log-Level** auf `debug`, starte das
  Add-on neu, versuch es noch einmal und sieh ins Log.
- **Display zeigt „PC-Anschluss“ und reagiert nicht:** Ein Scan wurde
  unterbrochen. Drück am Gerät „Stopp“.
- **Windows meldet beim Scannen „Papierstau“:** Die Auflösung ist zu hoch.
  Wähl höchstens 600 dpi.
- **Druck abbrechen:** Die angefangene Seite wird fertig gedruckt und
  ausgeworfen, danach ist Schluss. Was schon im Speicher des Druckers liegt,
  brichst du mit „Stopp“ am Gerät ab.
- **Add-on hängt:** Schalte im Add-on-Tab den **Watchdog** ein.
- **Im Modus `printer_app` klappt es nicht:** Probier den Modus `cups`.

## Für Entwickler

**Fertige Images:** Ohne weitere Einstellung baut Home Assistant das Add-on
selbst (einige Minuten). Alternativ baut der Workflow
`.github/workflows/build.yaml` bei jedem Push auf `main` das Image
`ghcr.io/zocker1012/amd64-cups-brother-mfc260c:<version>`. Stell das Paket
auf GitHub auf **Public** und ergänze in `config.yaml`
`image: "ghcr.io/zocker1012/{arch}-cups-brother-mfc260c"`. Danach gilt: erst
pushen, Workflow abwarten, dann in HA updaten.

**Scannertreiber:** `brscan2` und das Scan-Key-Tool lädt der Build von Brother
(mit Prüfsumme). Liegen die `.rpm`-Dateien in `drivers/`, nimmt er diese.

**Lizenzen:** Für private Nutzung musst du nichts beachten. Enthalten sind die
Brother-Treiber (unverändert mit `drivers/LICENSE-Brother.txt` weitergebbar),
CUPS, PAPPL und die Legacy Printer Application (Apache 2.0), AirSane (GPL-3.0,
Anpassung in `patches/`) sowie Ghostscript, SANE, Avahi und nginx aus Ubuntu
(GPL/AGPL/LGPL/BSD). Das CUPS-Logo ist eine Marke von OpenPrinting/Apple.
