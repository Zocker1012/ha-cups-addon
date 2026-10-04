# CUPS Addon (Brother MFC-260C)

Druck- und Scanserver für den per USB angeschlossenen **Brother MFC-260C**.
Drucken per **AirPrint / IPP Everywhere**, Scannen per **AirScan / eSCL** –
ohne Treiber auf den Geräten.

## Einrichtung

1. Drucker per USB an den Home-Assistant-Host anschließen und einschalten.
2. Add-on starten. Der Drucker wird automatisch als **MFC260C** angelegt
   (Papier A4) – auch wenn er erst später eingeschaltet wird.

Danach finden die Geräte im Netzwerk Drucker und Scanner von selbst:

| Gerät | Drucken | Scannen |
|---|---|---|
| Windows 10/11 | Einstellungen → Drucker & Scanner → Gerät hinzufügen (Treiber „Microsoft IPP Class Driver“ ist richtig) | ebenso, App „Windows-Scan“ |
| Android | direkt im Druckdialog | App „Mopria Scan“ |
| iPhone/iPad | direkt im Druckdialog | nur mit eSCL-fähiger App |
| macOS | Systemeinstellungen → Drucker & Scanner | Vorschau → Ablage → Von Scanner importieren |
| Linux | automatisch | Simple Scan (`sane-airscan`) |
| Browser | – | HA-Seitenleiste → Scanner |

## Weboberfläche und Anmeldung

Die Verwaltung erreichst du über die **HA-Seitenleiste** (dort bist du
automatisch angemeldet) oder direkt unter `http://<IP-von-HA>:631/`
(Admin-Seiten mit selbst signiertem Zertifikat – die Browser-Warnung ist
normal).

Wer sich direkt anmelden darf, legt **Anmeldung → Art** fest:

| Art | Modus `printer_app` | Modus `cups` |
|---|---|---|
| `homeassistant` (Standard) | nur über die HA-Seitenleiste | mit jedem HA-Benutzerkonto |
| `manual` | mit dem Passwort | mit Benutzername (Standard `print`) und Passwort |

Ohne Passwort bei `manual` erzeugt das Add-on eins und schreibt es ins Log.
Zum Drucken braucht niemand eine Anmeldung.

Die Brother-Optionen (Qualität, Medientyp, Graustufen …) stehen in der
Weboberfläche unter **Printing Defaults**, das Papierformat unter **Media**.

## Scanner

- **Glas oder Einzug** wählt der MFC-260C selbst: Liegt Papier im Einzug (das
  Display zeigt es an), scannt er von dort, sonst vom Glas. Für mehrere Seiten
  im Programm „Feeder“/Einzug und PDF wählen, sonst kommt nur die erste Seite.
- **Auflösung:** Optisch schafft das Gerät 600 dpi (Standardgrenze). 1200 dpi
  sind hochgerechnet und sehr langsam; mehr bietet das Add-on nicht an, da
  solche Scans scheitern.

### Scan-Menü am Gerät

Mit **Scan-Menü am Gerät → Scan-Menü nutzen** speichert das Menü **Scan** am
MFC-260C direkt in den eingestellten Ordner (Standard `/share/scans`, per
Samba unter „share“ erreichbar). Das Gerät meldet nur den gewählten Menüpunkt,
die Einstellungen kommen aus dem Add-on:

| Menüpunkt | Ergebnis |
|---|---|
| Datei, OCR, E-Mail | Format, Auflösung und Farbe aus den Einstellungen |
| Bild | JPEG in Farbe |

Mehrere Seiten aus dem Einzug werden als PDF eine Datei, als JPEG/PNG eine
Datei pro Seite. Nach jedem Scan sendet das Add-on das Ereignis
`cups_addon_scan` (`status`, `file`, `target`) an Home Assistant, z. B.:

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

Mit **Druckordner → Druckordner nutzen** wird jede Datei gedruckt, die im
Ordner landet (Standard `/share/print`, z. B. per Samba oder aus einer
Automation): PDF, PostScript, JPEG, PNG – immer auf A4, Farbe und Qualität aus
den Einstellungen. Danach liegt sie in `gedruckt/` bzw. `fehler/`.

## Druckerstatus in Home Assistant

Die **IPP-Integration** erkennt den Drucker automatisch (Einstellungen →
Geräte & Dienste) und liefert den Status. Tintenstände meldet der
Brother-Treiber nicht.

## Einstellungen

Die Gruppen in der YAML-Ansicht:

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
folder_printing:
  enabled: false
  path: /share/print      # unter /share oder /media
  color: color            # color | gray
  quality: normal         # draft | normal | fine
log_level: info           # debug | info | warning | error
```

**Modus:** `printer_app` ist der CUPS-3-Weg (Legacy Printer Application von
OpenPrinting) und der Normalfall. `cups` ist der klassische CUPS-Server als
Rückfallebene; dort den Drucker einmal selbst anlegen (Administration → Add
Printer → Brother MFC-260C, „Share This Printer“). Beide laufen auf Port 631.

## Fehlersuche

- **Drucker wird nicht gefunden:** Eingeschaltet und per USB verbunden? Wurde
  er gelöscht, das Add-on einmal neu starten.
- **Druck oder Scan klappt nicht:** **Log-Level** `debug` setzen, Add-on neu
  starten, wiederholen und das Log ansehen.
- **Display zeigt „PC-Anschluss“ und reagiert nicht:** Ein Scan wurde
  unterbrochen – am Gerät „Stopp“ drücken.
- **Windows meldet beim Scannen „Papierstau“:** Auflösung zu hoch, höchstens
  600 dpi wählen.
- **Druck abbrechen:** Die angefangene Seite wird fertig gedruckt und
  ausgeworfen, danach ist Schluss. Was schon im Speicher des Druckers liegt,
  mit „Stopp“ am Gerät abbrechen.
- **Add-on hängt:** Im Add-on-Tab den **Watchdog** einschalten.
- **Im Modus `printer_app` klappt es nicht:** Modus `cups` ausprobieren.

## Für Entwickler

**Fertige Images:** Ohne weitere Einstellung baut Home Assistant das Add-on
selbst (einige Minuten). Alternativ baut der Workflow
`.github/workflows/build.yaml` bei jedem Push auf `main` das Image
`ghcr.io/zocker1012/amd64-cups-brother-mfc260c:<version>`. Paket auf GitHub
auf **Public** stellen und in `config.yaml`
`image: "ghcr.io/zocker1012/{arch}-cups-brother-mfc260c"` ergänzen. Danach
erst pushen, Workflow abwarten, dann in HA updaten.

**Scannertreiber:** `brscan2` und das Scan-Key-Tool lädt der Build von Brother
(mit Prüfsumme). Liegen die `.rpm`-Dateien in `drivers/`, werden diese
genommen.

**Lizenzen:** Für private Nutzung ist nichts zu beachten. Enthalten sind die
Brother-Treiber (Weitergabe unverändert mit `drivers/LICENSE-Brother.txt`
erlaubt), CUPS/PAPPL/Legacy Printer Application (Apache 2.0), AirSane
(GPL-3.0, mit Anpassung in `patches/`) sowie Ghostscript, SANE, Avahi und
nginx aus Ubuntu (GPL/AGPL/LGPL/BSD). Das CUPS-Logo ist eine Marke von
OpenPrinting/Apple.
