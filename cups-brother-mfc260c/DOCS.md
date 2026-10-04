# CUPS Addon (Brother MFC-260C)

Druck- und Scanserver für den per USB angeschlossenen **Brother MFC-260C**.
Der Drucker wird im Netzwerk per **AirPrint / IPP Everywhere** angeboten –
iPhone, iPad, Android, macOS, Windows und Linux drucken ohne eigenen Treiber.
Der Scanner steht per **AirScan / eSCL** bereit.

## Modi

Über die Option `mode` wählst du, wie der Brother-Treiber betrieben wird:

| Modus | Was läuft | Wann nutzen |
|---|---|---|
| `printer_app` (Standard) | **Legacy Printer Application** von OpenPrinting (PAPPL). Das ist der für CUPS 3 vorgesehene Weg, alte PPD-Treiber weiter zu nutzen. | Normalfall |
| `cups` | Klassischer CUPS-Server (2.4) mit dem Brother-Treiber | Rückfallebene, falls im Modus `printer_app` etwas nicht klappt |

Beide Modi laufen auf Port **631**. Nach dem Umschalten das Add-on neu starten.
Die Drucker-Einrichtung wird je Modus getrennt gespeichert.

## Einrichtung

1. Drucker per USB an den Home-Assistant-Host anschließen und einschalten.
2. Anmeldung wählen (siehe unten).
3. Add-on starten.

### Modus `printer_app`

Mit `auto_setup: true` (Standard) legt das Add-on den Drucker automatisch als
**MFC260C** an – beim Start und auch im laufenden Betrieb, sobald der Drucker
per USB verbunden und eingeschaltet wird. Ein Neustart des Add-ons ist dafür
nicht nötig. Dazu prüft das Add-on alle 5 Sekunden den USB-Bus (nur ein paar
Dateien lesen, keine Netzwerk- oder Druckerabfragen). Sobald ein Drucker
eingerichtet ist, endet diese Überwachung bis zum nächsten Start des Add-ons.
Wer den Drucker später löscht, startet das Add-on einmal neu.

Manuell geht es in der Weboberfläche über **Add Printer**: Gerät „Brother
MFC-260C“ (USB) und Treiber „Brother MFC-260C, CUPS v1.1“ wählen.

Die Brother-Optionen (Qualität, Medientyp, Graustufen, Helligkeit …) stehen
unter **Printing Defaults** des Druckers zur Verfügung.

### Modus `cups`

Weboberfläche öffnen, **Administration → Add Printer**, den Brother
MFC-260C (USB) und das Modell „Brother MFC-260C CUPS v1.1“ wählen und
„Share This Printer“ aktivieren.

## Scanner

Mit `scanner: true` (Standard) stellt das Add-on den Scanner über
[AirSane](https://github.com/SimulPiscator/AirSane) per **AirScan/eSCL** bereit –
dem modernen, treiberlosen Scan-Standard (Gegenstück zu AirPrint/IPP Everywhere):

- **macOS**: Digitale Bilder oder Vorschau → „Ablage → Von Scanner importieren“
- **Windows 10/11**: Einstellungen → Drucker & Scanner → Gerät hinzufügen
- **Android**: App „Mopria Scan“
- **Linux**: über `sane-airscan` (z. B. Simple Scan)
- **iPhone/iPad**: iOS hat keine eingebaute Funktion dafür – eine eSCL-fähige
  App ist nötig
- **Browser**: in der HA-Seitenleiste unter „Scanner“ oder direkt
  `http://<IP-von-Home-Assistant>:8090/`

Der MFC-260C scannt optisch mit 600 dpi, alles darüber rechnet der Treiber
hoch. Der Treiber bietet bis zu 9600 dpi an – solche Scans werden riesig und
scheitern (Windows meldet dann „Papierstau“). Das Add-on bietet deshalb
höchstens `scan_max_resolution` an: Standard 600 dpi, die echte Auflösung des
Geräts. 1200 dpi (hochgerechnet, wie bei Brothers eigenem Windows-Treiber)
lässt sich einstellen, dauert aber sehr lange und bringt keine echten Details.

Der Scannertreiber (`brscan2`) und das Scan-Key-Tool werden beim Bauen des
Add-ons von Brother geladen und per Prüfsumme kontrolliert. Liegen die Dateien
`brscan2-0.2.5-1.x86_64.rpm` und `brscan-skey-0.3.5-0.x86_64.rpm` (oder
`-0.2.4-1`) im Ordner `drivers/` des Repositorys, werden stattdessen diese
verwendet. Ist beides nicht möglich, startet das Add-on ohne Scanner und meldet
das im Log.

### Scan-Menü am Gerät

Mit `scan_button: true` scannt das Menü **Scan** am MFC-260C direkt in den
`scan_folder` (Standard `/share/scans`, im Netzwerk über die Samba-Freigabe
„share“ erreichbar):

| Menüpunkt am Gerät | Ergebnis |
|---|---|
| **Datei** (sowie OCR, E-Mail) | Format, Auflösung und Farbe aus `scan_format`, `scan_resolution`, `scan_mode` |
| **Bild** | JPEG in Farbe, Auflösung aus `scan_resolution` |

Die Quelle bestimmt `scan_source`: Bei `auto` (Standard) wird vom
Vorlageneinzug gescannt, wenn dort Papier liegt, sonst vom Vorlagenglas.
Mehrere Seiten aus dem Einzug landen als PDF in einer Datei, als JPEG/PNG in
einer Datei pro Seite. Der Scan selbst läuft über AirSane – denselben Weg wie
in der Weboberfläche. Dort und unter Windows lässt sich die Quelle
(„Platen“/Flachbett oder „Feeder“/Einzug) direkt auswählen.

Nach jedem Scan sendet das Add-on das Ereignis `cups_addon_scan` an Home
Assistant (`status`, `file`, `target`) – z. B. für eine Benachrichtigung:

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

Die Menü-Erkennung übernimmt Brothers Scan-Key-Tool. Erscheint nach der Wahl
am Gerät nichts im Log, mit `log_level: debug` erneut versuchen und das Log
prüfen.

## Druckordner

Mit `print_folder: true` wird alles gedruckt, was im `print_folder_path`
(Standard `/share/print`) landet – z. B. per Samba vom PC oder aus einer
Home-Assistant-Automation. Unterstützt werden PDF, PostScript, JPEG und PNG.
Gedruckte Dateien wandern nach `gedruckt/`, nicht unterstützte oder
fehlgeschlagene nach `fehler/`.

## Druckerstatus in Home Assistant

Die eingebaute **IPP-Integration** von Home Assistant erkennt den Drucker
automatisch (Einstellungen → Geräte & Dienste) und liefert den Status als
Entität. Das funktioniert mit beiden Modi. Füllstände der Tinte meldet der
Brother-Linux-Treiber nicht.

## Weboberfläche und Anmeldung

- **Seitenleiste von Home Assistant** (Ingress): Startseite mit „Drucker“ und
  „Scanner“. Hier bist du in beiden Modi automatisch als Admin angemeldet –
  Home Assistant hat dich ja schon angemeldet.
- **Direkt**: `http://<IP-von-Home-Assistant>:631/`. Für Admin-Seiten
  wechselt die Oberfläche auf HTTPS mit einem selbst signierten Zertifikat –
  die Browser-Warnung ist normal.

Wer sich bei direktem Zugriff anmelden darf, legt die Option `auth` fest:

| `auth` | Modus `cups` | Modus `printer_app` |
|---|---|---|
| `homeassistant` (Standard) | Mit jedem **Home-Assistant-Benutzerkonto** (Benutzername und Passwort wie beim HA-Login) | Verwaltung **nur über die HA-Seitenleiste**; direkt im LAN ist sie gesperrt |
| `manual` | Mit `admin_username` (Standard `print`) und `admin_password` | Mit `admin_password` (die Printer Application kennt keine Benutzernamen) |

Ist bei `manual` kein `admin_password` gesetzt, erzeugt das Add-on ein
zufälliges Passwort und schreibt es beim Start ins Log.

Drucken selbst braucht in keinem Fall eine Anmeldung.

## Optionen

| Option | Beschreibung |
|---|---|
| `mode` | `printer_app` oder `cups` (siehe oben) |
| `auth` | `homeassistant` oder `manual` (siehe oben) |
| `admin_username` | Benutzername bei `auth: manual` (nur Modus `cups`), Standard `print` |
| `admin_password` | Passwort bei `auth: manual` |
| `auto_setup` | Drucker im Modus `printer_app` automatisch anlegen, auch beim Anstecken im laufenden Betrieb |
| `scanner` | Scanner per AirScan/eSCL bereitstellen |
| `scan_max_resolution` | Höchste angebotene Auflösung: 300, 600 oder 1200 dpi |
| `scan_button` | Scan-Menü am Gerät nutzen |
| `scan_folder` | Zielordner für Scans per Taste (unter `/share` oder `/media`) |
| `scan_format` | `pdf`, `jpeg` oder `png` |
| `scan_resolution` | 100, 150, 200, 300 oder 600 dpi |
| `scan_mode` | `color` oder `gray` |
| `scan_source` | `auto`, `flatbed` (Vorlagenglas) oder `adf` (Vorlageneinzug) |
| `print_folder` | Druckordner aktivieren |
| `print_folder_path` | Pfad des Druckordners (unter `/share` oder `/media`) |
| `log_level` | `debug`, `info`, `warning`, `error`. Bei `info` nur Meldungen des Add-ons und Warnungen; `debug` zeigt jede Verbindung und das Debug-Log des Brother-Treibers. |

## Fehlersuche

- **Drucker wird nicht gefunden:** Ist er eingeschaltet und per USB verbunden?
  Auf dem Host zeigt `lsusb` die USB-ID des Druckers. Weicht sie von der im
  Add-on hinterlegten `04f9:01d6` ab, muss der USB-Quirk in
  `rootfs/usr/share/cups/usb/brother-mfc260c.usb-quirks` angepasst werden.
- **Druck kommt nicht oder fehlerhaft:** `log_level: debug` setzen, Add-on neu
  starten, erneut drucken und das Log ansehen.
- **Scanner fehlt:** Im Log nach „Scanner:“ suchen. Fehlt der Treiber, siehe
  Abschnitt Scanner. Mit `log_level: debug` schreibt AirSane Details ins Log.
- **Windows meldet beim Scannen „Papierstau“:** Die gewählte Auflösung ist zu
  hoch. `scan_max_resolution` auf 600 lassen (Standard), das ist die echte
  Auflösung des Geräts.
- **Druckauftrag abbrechen:** Das Add-on beendet den Auftrag innerhalb weniger
  Sekunden; die gerade gedruckte Seite wird abgeschlossen und ausgeworfen,
  weitere Seiten kommen nicht. Was schon komplett im Drucker liegt, druckt der
  MFC-260C aus seinem Speicher zu Ende – dann am Gerät „Stopp“ drücken.
- **Add-on hängt:** Im Add-on-Tab den **Watchdog** einschalten – der Supervisor
  startet das Add-on dann neu, wenn Port 631 nicht mehr antwortet.
- **Im Modus `printer_app` klappt es nicht:** `mode: cups` setzen, das Add-on
  neu starten und den Drucker dort einrichten.

## Umstieg von Version 1.x

Die Druckerkonfiguration liegt jetzt im Add-on-eigenen Speicher (`/data`,
in Backups enthalten) statt im Home-Assistant-Konfigurationsordner. Den
Drucker deshalb einmal neu einrichten (im Modus `printer_app` passiert das
automatisch). Der alte Ordner `cups/` im Home-Assistant-Konfigurationsordner
wird nicht mehr benutzt und kann gelöscht werden.

## Fertige Images (ohne Bauen auf dem Gerät)

Ohne weitere Einstellung baut der Supervisor das Add-on beim Installieren und
bei jedem Update selbst (einige Minuten, Downloads von Ubuntu, GitHub und
Brother). Alternativ baut GitHub das Image:

1. Der Workflow `.github/workflows/build.yaml` baut bei jedem Push auf `main`
   das Image `ghcr.io/zocker1012/amd64-cups-brother-mfc260c:<version>` und
   lädt es in die GitHub Packages des Repositorys.
2. Auf GitHub unter **Packages → amd64-cups-brother-mfc260c → Package
   settings** die Sichtbarkeit auf **Public** stellen. Home Assistant kann das
   Image sonst nicht laden.
3. In `config.yaml` die Zeile
   `image: "ghcr.io/zocker1012/{arch}-cups-brother-mfc260c"` ergänzen.

Ab dann lädt Home Assistant nur noch das fertige Image. Wichtig: Jede neue
`version` in `config.yaml` braucht ein fertig gebautes Image mit diesem Tag,
sonst schlägt das Update fehl. Erst pushen, Workflow abwarten, dann updaten.

## Lizenzen

Der Code dieses Add-ons (Skripte, Konfiguration) stammt aus diesem Repository.
Im Image stecken außerdem:

| Komponente | Lizenz | Hinweis |
|---|---|---|
| Brother-Druckertreiber MFC-260C (`drivers/*.deb`) | Brother-Lizenz, GPL (cupswrapper-Skripte) | Weitergabe unveränderter Dateien mit Lizenztext erlaubt (`drivers/LICENSE-Brother.txt`) |
| Brother-Scannertreiber `brscan2`, Scan-Key-Tool `brscan-skey` | Brother-Lizenzen, GPL (SANE-Teil) | wie oben; beim Bauen von Brother geladen oder aus `drivers/` |
| CUPS, cups-filters, libppd, libcupsfilters | Apache 2.0 | Ubuntu-Pakete |
| PAPPL, Legacy Printer Application (pappl-retrofit) | Apache 2.0 | Ubuntu-Pakete |
| AirSane | GPL-3.0 | aus dem Quellcode gebaut (Version im Dockerfile), mit kleiner Anpassung (`patches/`) |
| Ghostscript, SANE, Avahi, nginx u. a. | AGPL/GPL/LGPL/BSD | Ubuntu-Pakete |
| Basis-Image `amd64-base-ubuntu` | Apache 2.0 | Home Assistant |
| CUPS-Logo (`icon.png`, `logo.png`) | Marke von OpenPrinting/Apple | für private Nutzung unkritisch |

Für die private Nutzung ist nichts weiter zu beachten. Wer fertige Images
öffentlich anbietet (z. B. über GitHub Packages), gibt damit GPL-Software weiter
und sollte auf die Quellen verweisen – die Links stehen im Dockerfile.
