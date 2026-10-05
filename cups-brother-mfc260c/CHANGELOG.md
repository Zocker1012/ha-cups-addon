# Changelog

## 2.12.0

### Neu

- Texterkennung auch für die Menüpunkte „Datei“ und „E-Mail“ einschaltbar
  (Standard aus; bei „Text“ Standard an). Sprache und automatisches Drehen
  gelten für alle und stehen jetzt unter „Scan-Menü am Gerät“ – bisherige
  Werte werden übernommen.

## 2.11.0

### Geändert

- Einstellungen übersichtlicher: Jeder Menüpunkt des Scan-Menüs hat eine
  eigene Gruppe („Scan-Menü: Datei“, „Bild“, „Text“, „E-Mail“). Bei jedem
  Schalter steht direkt dabei, was „an“ und „aus“ bewirken.
- Bisherige Einstellungen werden beim ersten Start automatisch übernommen.

### Behoben

- Übernahme alter Einstellungen (2.4.x): Ausgeschaltete Optionen sprangen
  dabei auf den Standard zurück.

## 2.10.3

### Behoben

- Scan-Menü am Gerät über 300 dpi (z. B. 600 dpi): Es wurde nur das obere
  linke Viertel der Seite gescannt. Ursache war ein Fehler in AirSane, das
  ohne Bereichsangabe die volle Fläche immer für 300 dpi berechnet hat –
  behoben per Patch (`patches/airsane-default-region.patch`).
- Während eines Scans ist wieder die `.part`-Datei im Scan-Ordner zu sehen.

## 2.10.2

### Geändert

- Einstellungen und Log heißen jetzt wie die Menüpunkte am MFC-260C: Datei,
  Bild, Text und E-Mail. „Text“ ist Brothers Menüpunkt für Texterkennung
  (vorher hier „OCR“ genannt).

## 2.10.1

### Geändert

- Scan-Menü am Gerät: Gescannt wird jetzt immer als PDF in einem Durchgang –
  der Weg, der am MFC-260C zuverlässig läuft. JPEG/PNG und die Texterkennung
  entstehen danach aus dem PDF. Vorher wurden Bilder Seite für Seite geholt,
  wobei das Gerät bei „PC-Anschluss“ hängen bleiben konnte.
- „Scan-Menü nutzen“ ist jetzt standardmäßig an. Ist es aus, wartet das Gerät
  nach der Wahl im Menü vergeblich bei „PC-Anschluss“.

## 2.10.0

### Neu

- Texterkennung für den Menüpunkt „OCR“ am Gerät (Tesseract, Deutsch und
  Englisch): PDF wird durchsuchbar, bei JPEG/PNG kommt eine `.txt`-Datei dazu.
  Verkehrt herum oder quer liegende Seiten werden vorher automatisch gedreht.
  Einstellungen: OCR – Texterkennung, Sprache, Seiten automatisch drehen.

## 2.9.0

### Neu

- Scan-Menü am Gerät: Jeder Menüpunkt (Datei, Bild, OCR, E-Mail) hat eigene
  Einstellungen für Format, Auflösung und Farbe. Standards: Datei PDF/300/
  Farbe, Bild JPEG/300/Farbe, OCR PDF/300/Graustufen, E-Mail PDF/150/Farbe.

## 2.8.0

### Neu

- Scan-Menü am Gerät: Der Menüpunkt „Bild“ hat jetzt eigene Einstellungen
  für Format, Auflösung und Farbe (Standard JPEG, 300 dpi, Farbe). Datei,
  OCR und E-Mail teilen sich die übrigen (Standard PDF, 300 dpi, Farbe).

## 2.7.0

### Neu

- Druckordner: Papierformat wählbar (A4, A5, A6, Letter, Legal, Foto 10x15,
  13x18, 9x13), Standard A4.
- Scan-Menü am Gerät: Farbe für den Menüpunkt „Bild“ einstellbar
  (Standard Farbe).

### Geändert

- Dokumentation durchgehend in der Du-Form und gekürzt.
- Log-Meldungen sprechen vom „Scan-Menü“ statt von der „Scan-Taste“.

## 2.6.0

### Behoben

- Papierformat (Modus `printer_app`): Der Brother-Treiber bekam das Format
  des Auftrags nicht mit und druckte immer mit dem Standard „Letter“. Ein
  kleiner Vorschalt-Filter gibt das Format jetzt weiter (A4, A5, randlos,
  Fotoformate …). Standard ist A4; ein schon eingerichteter Drucker wird
  einmalig auf A4 gestellt.

### Neu

- Druckordner: Einstellungen für Farbe (Farbe/Graustufen) und Qualität
  (Entwurf/Normal/Fein); gedruckt wird immer auf A4.

## 2.5.0

### Geändert

- Einstellungen in aufklappbare Gruppen sortiert: Drucker, Anmeldung,
  Scanner, Scan-Menü am Gerät, Druckordner. Kürzere Beschreibungen, Details
  in der Dokumentation.
- Bisherige Einstellungen werden beim ersten Start automatisch übernommen.
- Höchste Scan-Auflösung: nur noch 600 oder 1200 dpi (300 war nicht sinnvoll).

## 2.4.2

### Behoben

- Scan-Menü am Gerät: Gerät blieb bei „PC-Anschluss“ hängen, wenn mit
  `scan_source: flatbed` aus dem Einzug gescannt wurde. Der MFC-260C wählt
  die Quelle selbst (Papier im Einzug → Einzug, sonst Vorlagenglas); das
  Add-on holt jetzt immer alle Seiten ab. Die Option `scan_source` entfällt
  deshalb wieder.
- Scan-Menü wartet, bis der Scanner bereit ist (z. B. kurz nach einem Scan
  oder einem Neustart des Scanner-Dienstes), statt sofort aufzugeben.
- Stürzt der Scanner-Dienst ab, steht der Grund jetzt im Log.

## 2.4.1

### Behoben

- Option `scan_source` ist zurück: Der MFC-260C hat einen Vorlageneinzug
  (in 2.4.0 versehentlich entfernt). Neuer Standard `auto` scannt vom
  Einzug, wenn dort Papier liegt, sonst vom Vorlagenglas.

## 2.4.0

### Behoben

- Scannen unter Windows mit hoher Auflösung: Der Brother-Treiber meldet
  hochgerechnete Auflösungen bis 9600 dpi. Ein solcher Scan wird riesig und
  bricht ab, Windows zeigt dann „Papierstau“. Der Scanner bietet jetzt
  höchstens 600 dpi an, die echte Auflösung des MFC-260C (einstellbar bis
  1200 dpi).

### Neu

- Option `scan_max_resolution` (300/600/1200 dpi): höchste Auflösung, die
  der Scanner im Netzwerk anbietet.
- Lizenzhinweise in der Dokumentation und `drivers/LICENSE-Brother.txt`.
- GitHub-Workflow, der fertige Images baut (siehe Dokumentation, „Fertige
  Images“). Das Add-on wird weiterhin auf dem Gerät gebaut, bis das Image
  in `config.yaml` eingetragen ist.

### Geändert

- Option `scan_source` entfernt.
- Das Scan-Menü am Gerät gilt nicht mehr als experimentell.

## 2.3.2

### Geändert

- Ruhigeres Log: Bei `log_level: info` schreibt die Printer Application nur
  noch Warnungen (statt mehrerer Zeilen pro Verbindung, z. B. bei jeder
  Abfrage der HA-IPP-Integration). CUPS protokolliert Zugriffe nur noch für
  Aktionen. Alle Details weiterhin mit `log_level: debug`.
- Abbrechen wird während des Drucks jede Sekunde statt alle drei Sekunden
  geprüft – es landen weniger Restdaten im Drucker.

## 2.3.1

### Behoben

- Abbrechen: Die angefangene Seite wird jetzt sauber abgeschlossen und
  ausgeworfen, statt im Drucker hängen zu bleiben. Der Wächter beendet dafür
  zuerst nur Ghostscript; der Brother-Filter schließt die Seite dann selbst ab.
- Scan-Taste mit Brother Scan-Key-Tool 0.3.x: Die Konfiguration heißt dort
  `brscan-skey.config` und wurde bisher nicht angepasst – Scans landeten in
  Brothers Standardordner. Jetzt werden beide Versionen eingerichtet, und
  Scans aus dem Standardordner werden zusätzlich in den Scan-Ordner verschoben.

## 2.3.0

### Behoben

- Druckaufträge abbrechen (Modus `printer_app`): Die Legacy Printer Application
  ließ den Brother-Filter nach dem Abbruch weiterlaufen, die Seite wurde
  trotzdem gedruckt. Ein Wächter beendet die Filterkette jetzt sofort.
- Scan-Taste: scannt jetzt über AirSane (wie die Weboberfläche) statt über
  einen eigenen Zugriff auf den Scanner – Scans landen zuverlässig im
  Scan-Ordner. Menüpunkt „Bild“ liefert JPEG in Farbe.
- `build.yaml` entfernt (vom Supervisor abgekündigt); das Basis-Image steht
  jetzt im Dockerfile.

### Neu

- Option `scan_source`: Vorlagenglas oder Vorlageneinzug für die Scan-Taste.

### Geändert

- mDNS/AirPrint nur noch auf den LAN-Schnittstellen statt auch auf internen
  Docker-/Home-Assistant-Netzen (weniger Log, keine internen Ankündigungen).

## 2.2.0

### Neu

- Scanner: AirSane stellt den Scanner des MFC-260C per AirScan/eSCL bereit
  (macOS, Windows, Android/Mopria, Linux) und im Browser bzw. in der
  HA-Seitenleiste. Brother-Scannertreiber `brscan2` wird beim Bauen von Brother
  geladen und per Prüfsumme kontrolliert.
- Scan-Taste am Gerät (experimentell): scannt in einen einstellbaren Ordner
  und meldet das Ereignis `cups_addon_scan` an Home Assistant.
- Druckordner: Dateien in `/share/print` (einstellbar) werden automatisch
  gedruckt.
- Ingress-Startseite mit „Drucker“ und „Scanner“.
- Watchdog: Der Supervisor kann das Add-on neu starten, wenn Port 631 nicht
  mehr antwortet (Schalter im Add-on-Tab).

### Geändert

- USB-Überwachung der Auto-Einrichtung endet, sobald ein Drucker eingerichtet
  ist.
- Zugriff auf `share` und `media` für Druck- und Scanordner.

## 2.1.0

### Neu

- Auto-Einrichtung erkennt den Drucker jetzt auch im laufenden Betrieb: Das
  Add-on beobachtet den USB-Bus und legt den Drucker an, sobald er verbunden
  und eingeschaltet wird – ohne Neustart. (PAPPL bzw. CUPS 3 selbst erkennen
  neue USB-Drucker nur beim Start.)
- Option `auth`: Anmeldung mit Home-Assistant-Benutzerkonten (`homeassistant`,
  Standard) oder mit eigenem Benutzernamen/Passwort (`manual`, neue Option
  `admin_username`).
- HA-Seitenleiste (Ingress) jetzt auch im Modus `printer_app` ohne
  zusätzlichen Login.

### Geändert

- Lokaler Benutzer `print` mit Systempasswort entfällt; die Anmeldung prüft
  das Add-on selbst (PAM). Im Modus `printer_app` mit `auth: homeassistant` ist
  die Verwaltung nur noch über die HA-Seitenleiste möglich.
- Standard ist jetzt `auth: homeassistant`. Wer das in 2.0 gesetzte
  `admin_password` weiter nutzen will, stellt `auth: manual` ein.

## 2.0.0

### Breaking

- Basis-Image: Ubuntu 26.04 LTS (`ghcr.io/home-assistant/amd64-base-ubuntu`)
  statt Debian 12. Damit CUPS 2.4.16, cups-filters 2.x und die Legacy Printer
  Application als Paket.
- Druckerkonfiguration liegt jetzt in `/data` (Add-on-Speicher, in Backups
  enthalten) statt in `/config/cups` (HA-Konfigurationsordner). Drucker muss
  einmal neu eingerichtet werden.
- Kein festes Passwort `print`/`print` mehr: Option `admin_password`, sonst
  zufällig erzeugt (steht im Log).

### Neu

- Modus `printer_app` (Standard): Brother-Treiber in der Legacy Printer
  Application (PAPPL, CUPS-3-Weg) mit AirPrint/IPP Everywhere.
- Modus `cups`: klassisches CUPS als Rückfallebene, umschaltbar per Option.
- Automatische Einrichtung des per USB angeschlossenen MFC-260C (`auto_setup`).
- Ingress: Weboberfläche in der Home-Assistant-Seitenleiste.
- `log_level`; bei `debug` landet auch das Brother-Treiber-Log im Add-on-Log.
- CUPS-Logs gehen ins Add-on-Log.

### Verbessert / behoben

- `cupsd.conf` wird bei jedem Start aus dem Image übernommen, Updates der
  Konfiguration kommen also an.
- USB-Quirk korrigiert (ungültiges `usbfs` entfernt; nur eine Zeile pro Gerät).
- Avahi: Reflector, Wide-Area und Workstation-Einträge aus – keine
  mDNS-Konflikte mehr mit dem Home-Assistant-Host.
- nginx lauscht nicht mehr offen auf Port 8080, sondern nur für den
  Ingress-Proxy von Home Assistant.
- Weniger Rechte: keine zusätzlichen Capabilities, AppArmor nicht mehr
  abgeschaltet, keine Zugriffe auf `config`, `share` und `ssl`.
- Unnötige Pakete entfernt (cups-pdf, perl, überflüssige i386-Bibliotheken),
  `psutils` ergänzt (N-up im Brother-Treiber).
- Build bricht ab, wenn der Brother-Treiber nicht sauber installiert ist.
