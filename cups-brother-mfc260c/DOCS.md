# CUPS Druck- & Scanserver (Brother MFC-260C)

Druck- und Scanserver für deinen per USB angeschlossenen **Brother MFC-260C**.
Du druckst per **AirPrint / IPP Everywhere** und scannst per **AirScan / eSCL**
– ohne Treiber auf deinen Geräten.

## Einrichtung

1. Schließ den Drucker per USB an deinen Home-Assistant-Rechner an und schalte
   ihn ein.
2. Starte das Add-on. Es legt den Drucker automatisch als **MFC260C** an
   (Papier A4) – auch wenn du ihn erst später einschaltest.

Danach finden deine Geräte Drucker und Scanner im Netzwerk von selbst. Der
Server meldet sich dabei als `ha-cups-addon.local`:

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

Ist **Scan-Menü am Gerät → Scan-Menü nutzen** an (Standard), speichert das Menü
**Scan** am MFC-260C direkt in deinen Scan-Ordner (Standard `/share/scans`,
per Samba unter „share“ erreichbar) – je Menüpunkt in einem Unterordner
`Datei/`, `Bild/`, `Text/` bzw. `E-Mail/` (abschaltbar). Scans vom PC, Handy
oder aus der Weboberfläche landen nicht hier, sondern direkt auf dem Gerät,
mit dem du scannst. Das Gerät meldet nur den gewählten Menüpunkt, alles andere
stellst du im Add-on ein:

| Menüpunkt | Standard (Format, Auflösung, Farbe) | Texterkennung |
|---|---|---|
| Datei | PDF, 300 dpi, Farbe | einstellbar, aus |
| Bild | JPEG, 300 dpi, Farbe | – |
| Text | PDF, 300 dpi, Graustufen | einstellbar, an |
| E-Mail | PDF, 150 dpi, Farbe, verkleinert (kleine Datei) | einstellbar, aus |

Jeden Menüpunkt kannst du frei auf PDF, JPEG oder PNG, 100–600 dpi und
Farbe oder Graustufen einstellen. „E-Mail“ speichert nur in den Ordner, Mails
verschickt das Add-on nicht.

**Qualität und Dateigröße:**

| Stellschraube | Wirkung |
|---|---|
| Auflösung, Farbe | bestimmen die Datenmenge (Graustufen etwa ⅓) |
| Format | PDF und PNG verlustfrei, JPEG Qualität 90 (JPEG ist immer verlustbehaftet) |
| Verkleinern (aus = beste Qualität, Standard) | an: Seiten als JPEG Qualität 75 – der einzige Schalter mit Qualitätsverlust |
| Texterkennung | fügt nur Text hinzu, die Bildqualität bleibt gleich |

Eine Farbseite mit 300 dpi hat als verlustfreies PDF etwa 8–10 MB, verkleinert
etwa 1 MB. Verkleinern lohnt sich vor allem bei Dokumenten; bei Fotos mit
feinen Farbverläufen lieber aus lassen. Bei PNG hat der Schalter keine
Wirkung.

**Texterkennung:** Ein PDF bekommt eine unsichtbare Textebene – du kannst
darin suchen und Text kopieren, und z. B. Paperless findet den Inhalt. Bei
JPEG/PNG kommt der erkannte Text als `.txt`-Datei dazu. Verkehrt herum oder
quer eingelegte Seiten dreht das Add-on vorher verlustfrei gerade. Sprache und
Drehen stellst du einmal unter **Scan-Menü am Gerät** ein. Die Erkennung
braucht je Seite einige Sekunden. Bei „Bild“ gibt es sie nicht – Fotos
enthalten kaum Text, und das Drehen könnte sie falsch herum stellen.

Mehrere Seiten aus dem Einzug landen als PDF in einer Datei, als JPEG/PNG in
einer Datei pro Seite.

**Leere Seiten entfernen** (Standard aus) lässt komplett leere Seiten weg,
etwa leere Rückseiten aus dem Einzug. So arbeitet die Erkennung:

- Sie greift nur bei Scans mit mehreren Seiten, und es bleibt immer
  mindestens eine Seite – auch wenn alle leer wirken.
- Jede Seite wird unabhängig von der Scan-Auflösung bei 150 dpi geprüft, und
  zwar in Farbe: Rot, Grün und Blau einzeln.
- Als Inhalt zählt alles, was sich deutlich vom Papierhintergrund abhebt –
  auch heller Bleistift, Textmarker oder ein hellblauer Stempel. Leicht
  getöntes Papier wird dabei als Hintergrund erkannt.
- Ein schmaler Rand (2 %) wird ignoriert, weil dort oft Schatten vom Scanner
  liegen.
- Eine Seite gilt nur als leer, wenn praktisch nichts darauf ist (ein paar
  Staubkörner). Schon eine kleine Seitenzahl reicht, damit sie bleibt – im
  Zweifel wird nichts entfernt.

Im Log steht, welche Seiten entfernt wurden (z. B. `Leere Seite(n) entfernt:
2`). Sehr blasse Striche auf einer sonst leeren Seite können trotzdem als leer
gelten; wer nichts riskieren will, lässt die Funktion aus.

Nach jedem Scan sendet das Add-on das Ereignis `cups_addon_scan` (`status`,
`file`, `target` = `file`, `image`, `ocr` für Text oder `email`) an Home
Assistant, z. B. für eine Benachrichtigung:

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
gedruckt, die du in den Ordner legst (Standard `/share/print`). Möglich sind
PDF, PostScript, JPEG und PNG. Papierformat (Standard A4), Farbe und Qualität
stellst du im Add-on ein.

So kommen Dateien in den Ordner:

- **Vom PC** über das Add-on „Samba share“: im Explorer
  `\\<IP-von-HA>\share\print` öffnen und die Datei hineinkopieren.
- **Aus Home Assistant**, z. B. per Automation mit der Aktion
  `downloader.download_file`, wenn der Download-Ordner der
  Downloader-Integration auf `/share` zeigt (Unterordner `print`).

Gedruckt wird, sobald die Datei vollständig geschrieben ist. Die Datei bleibt
im Ordner, bis der Drucker mit ihr fertig ist, und liegt dann in `gedruckt/`.
Abgebrochene, fehlgeschlagene oder nicht unterstützte Dateien landen in
`fehler/` – ebenso eine Datei, deren Druck ein Neustart des Add-ons
unterbrochen hat (sie wird nicht doppelt gedruckt).

## Aufräumen

Mit **Aufräumen → Aufräumen nutzen** (Standard aus) räumt das Add-on einmal
täglich auf, in zwei Stufen:

1. Dateien, die älter als die eingestellten Tage sind (Standard 30), wandern
   in den Ordner `Papierkorb/` im Scan- bzw. Druckordner. Die Unterordner
   bleiben erhalten, du findest also `Papierkorb/Datei/…` wieder.
2. Was länger als die eingestellten Tage (Standard 30) im Papierkorb liegt,
   wird endgültig gelöscht.

Die Tage stellst du getrennt für Scans, `gedruckt/` und `fehler/` ein, 0 heißt
nie. Gezählt wird das Alter jeder einzelnen Datei: bei Scans ab dem Scan, bei
gedruckten Dateien ab dem Drucken. Legst du selbst ältere Dateien in den
Scan-Ordner, zählt ihr ursprüngliches Datum. Dateien im Druckordner, die noch
gedruckt werden sollen, rührt das Aufräumen nie an. Zum Wiederherstellen
schiebst du eine Datei einfach aus dem Papierkorb zurück.

## Druckerstatus in Home Assistant

Die **IPP-Integration** findet den Drucker automatisch (Einstellungen →
Geräte & Dienste) und zeigt seinen Status. Tintenstände meldet der
Brother-Treiber nicht.

**Entitäten per MQTT:** Läuft das Mosquitto-Add-on, meldet sich das Add-on als
Gerät **Brother MFC-260C** an (Einstellungen → Geräte & Dienste → MQTT).
Abschalten unter **MQTT-Entitäten** in den Add-on-Einstellungen. Die Entitäten
sind in beiden Druckmodi gleich:

| Entität | Inhalt |
|---|---|
| `binary_sensor.mfc260c_eingeschaltet` | Drucker an/aus (USB) |
| `sensor.mfc260c_status` | Bereit, Druckt, Wartet auf Drucker, Aus |
| `sensor.mfc260c_druckauftraege` | Zahl der wartenden Aufträge |
| `sensor.mfc260c_letzter_scan` | Dateiname, dazu Pfad, Menüpunkt und Zeit als Attribute |
| `sensor.mfc260c_druckmodus` | `printer_app` oder `cups` (Diagnose) |

Beispiel für eine schaltbare Steckdose – an bei einem Auftrag, aus 15 Minuten
nach dem letzten:

```yaml
triggers:
  - trigger: numeric_state
    entity_id: sensor.mfc260c_druckauftraege
    above: 0
    id: an
  - trigger: state
    entity_id: sensor.mfc260c_druckauftraege
    to: "0"
    for: "00:15:00"
    id: aus
actions:
  - action: "switch.turn_{{ 'on' if trigger.id == 'an' else 'off' }}"
    target: {entity_id: switch.drucker_steckdose}
```

Ist der Drucker aus, bleiben Aufträge in der Warteschlange und werden nach dem
Einschalten gedruckt – in beiden Modi. Das Log meldet Ein/Aus und wartende
Aufträge, und Home Assistant bekommt sofort das Ereignis `cups_addon_printer`:

| `status` | Bedeutung |
|---|---|
| `job_queued` | ein Auftrag ist angekommen (vorher war keiner da) |
| `jobs_done` | alle Aufträge sind erledigt |
| `printer_on` / `printer_off` | Drucker eingeschaltet / ausgeschaltet (USB) |

Dazu kommen `jobs` (Zahl der Aufträge) und `printer_on` (`true`/`false`).
Ohne MQTT lässt sich die Steckdose genauso über diese Ereignisse schalten:

```yaml
mode: restart
triggers:
  - trigger: event
    event_type: cups_addon_printer
    event_data: {status: job_queued}
    id: an
  - trigger: event
    event_type: cups_addon_printer
    event_data: {status: jobs_done}
    id: aus
actions:
  - choose:
      - conditions: {condition: trigger, id: an}
        sequence:
          - action: switch.turn_on
            target: {entity_id: switch.drucker_steckdose}
      - conditions: {condition: trigger, id: aus}
        sequence:
          - delay: "00:15:00"
          - action: switch.turn_off
            target: {entity_id: switch.drucker_steckdose}
```

In beiden Beispielen bleibt der Drucker an, wenn während der 15 Minuten ein
neuer Auftrag kommt. Zum Scannen muss der Drucker eingeschaltet sein.

Statt der Ereignisse geht auch der Status der IPP-Integration (Abfrage etwa
jede Minute): Wartet ein Auftrag auf den ausgeschalteten Drucker, zeigt sie im
Modus `printer_app` „Angehalten“ und im Modus `cups` „Druckt“; danach wieder
„Untätig“.

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
  enabled: true
  folder: /share/scans    # unter /share oder /media
  subfolders: true        # Unterordner Datei/, Bild/, Text/, E-Mail/
  remove_blank: false     # leere Seiten entfernen
  language: deu_eng       # Texterkennung: deu_eng | deu | eng
  rotate: true            # Texterkennung: Seiten automatisch drehen
scan_file:                # Menüpunkt "Datei"
  format: pdf             # pdf | jpeg | png
  resolution: "300"       # 100 | 150 | 200 | 300 | 600
  color: color            # color | gray
  ocr: false              # Texterkennung
  compress: false         # Verkleinern (pdf, jpeg)
scan_image:               # Menüpunkt "Bild" (ohne Texterkennung)
  format: jpeg
  resolution: "300"
  color: color
  compress: false
scan_text:                # Menüpunkt "Text"
  format: pdf
  resolution: "300"
  color: gray
  ocr: true
  compress: false
scan_email:               # Menüpunkt "E-Mail"
  format: pdf
  resolution: "150"
  color: color
  ocr: false
  compress: true
folder_printing:
  enabled: false
  path: /share/print      # unter /share oder /media
  paper: a4               # a4 | a5 | a6 | letter | legal |
                          # photo_10x15 | photo_13x18 | photo_9x13
  color: color            # color | gray
  quality: normal         # draft | normal | fine
cleanup:
  enabled: false
  scans_days: 30          # Tage bis Papierkorb (0 = nie)
  printed_days: 30
  failed_days: 30
  trash_days: 30          # Tage im Papierkorb bis zum Löschen
mqtt:
  enabled: true           # Entitäten per MQTT (mit Mosquitto)
log_level: info           # debug | info | warning | error
```

**Modus:** `printer_app` ist der CUPS-3-Weg (Legacy Printer Application von
OpenPrinting) und der Normalfall. `cups` ist der klassische CUPS-Server als
Rückfallebene, falls die Printer Application einmal Probleme macht. Beide
laufen auf Port 631, richten den Drucker automatisch ein (A4, freigegeben) und
funktionieren mit Druckordner, Scanner und Scan-Menü gleich. Nach dem
Umschalten den Drucker auf deinen Geräten einmal neu hinzufügen, falls er
nicht mehr gefunden wird.

## Fehlersuche

- **Drucker wird nicht gefunden:** Ist er eingeschaltet und per USB verbunden?
  Hast du ihn gelöscht, starte das Add-on einmal neu.
- **Druck oder Scan klappt nicht:** Setz **Log-Level** auf `debug`, starte das
  Add-on neu, versuch es noch einmal und sieh ins Log.
- **Display zeigt „PC-Anschluss“ und reagiert nicht:** Ist **Scan-Menü
  nutzen** an? Sonst wartet das Gerät vergeblich. Ansonsten wurde ein Scan
  unterbrochen – drück am Gerät „Stopp“.
- **Scan liegt als PDF statt im eingestellten Format vor:** Ein
  Verarbeitungsschritt ist fehlgeschlagen. Damit nichts verloren geht,
  speichert das Add-on den Scan dann unverändert; den Grund findest du im Log.
- **Windows meldet beim Scannen „Papierstau“:** Die Auflösung ist zu hoch.
  Wähl höchstens 600 dpi.
- **Druck abbrechen:** Die angefangene Seite wird fertig gedruckt und
  ausgeworfen, danach ist Schluss. Was schon im Speicher des Druckers liegt,
  brichst du mit „Stopp“ am Gerät ab.
- **Add-on hängt:** Schalte im Add-on-Tab den **Watchdog** ein.
- **Im Modus `printer_app` klappt es nicht:** Probier den Modus `cups`.
- **Nach einem Update geht etwas nicht mehr:** Mit „Vor dem Update ein Backup
  erstellen“ (Häkchen beim Update) sicherst du die alte Version. Über
  Einstellungen → System → Backups stellst du sie wieder her – Version und
  Einstellungen des Add-ons kommen dann zurück.

## Für Entwickler

**Fertige Images:** Home Assistant baut das Add-on nicht selbst, sondern lädt
das fertige Image `ghcr.io/zocker1012/amd64-cups-brother-mfc260c:<version>`
(Eintrag `image:` in `config.yaml`). Es entsteht bei jedem Push auf `main`
durch den Workflow `.github/workflows/build.yaml`. Deshalb gilt bei Änderungen:
Version erhöhen, pushen, Workflow abwarten, erst dann in HA updaten. Zum
Selbstbauen in HA die Zeile `image:` entfernen.

**Brother-Treiber:** Alle vier Pakete (Drucker: LPR und CUPS-Wrapper als
`.deb`, Scanner: `brscan2` und Scan-Key-Tool `brscan-skey` als `.rpm`) liegen
unverändert in `drivers/`, Brothers Quellcode der GPL-Teile in
`drivers/source/`. Der Build prüft die Prüfsummen und lädt nichts von Brother.
Die Scannerpakete werden nur ausgepackt, die Einrichtung übernimmt das
Dockerfile.

**Lizenzen:** Der eigene Code des Add-ons (Skripte, Dockerfile, Startseite,
Symbol, Doku) steht unter der GPL-3.0 oder später (`LICENSE` im Repository).
Enthalten sind außerdem die Brother-Treiber (teils GPL-2.0, teils
Brother-Lizenz, weitergeben erlaubt; je Paket in `drivers/LICENSE-Brother.txt`),
CUPS, PAPPL und die Legacy Printer Application (Apache 2.0), AirSane (GPL-3.0,
Anpassungen in `patches/`), Tesseract und qpdf (Apache 2.0), img2pdf (LGPL-3.0), Mosquitto-Clients
(EPL-2.0/EDL-1.0)
sowie Ghostscript, SANE, Avahi und nginx aus Ubuntu (AGPL/GPL/LGPL/BSD).

**Marken:** CUPS und AirPrint sind Marken von Apple Inc., Brother und MFC-260C
von Brother Industries, Ltd. Sie stehen hier nur zur Beschreibung; das Add-on
ist ein privates Projekt ohne Verbindung zu OpenPrinting, Apple oder Brother.
