# CUPS Addon (Brother MFC-260C)

Druckserver für den per USB angeschlossenen **Brother MFC-260C**. Der Drucker
wird im Netzwerk per **AirPrint / IPP Everywhere** angeboten – iPhone, iPad,
Android, macOS, Windows und Linux drucken ohne eigenen Treiber.

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
nicht nötig. Die Auto-Einrichtung greift nur, solange noch kein Drucker
angelegt ist.

Manuell geht es in der Weboberfläche über **Add Printer**: Gerät „Brother
MFC-260C“ (USB) und Treiber „Brother MFC-260C, CUPS v1.1“ wählen.

Die Brother-Optionen (Qualität, Medientyp, Graustufen, Helligkeit …) stehen
unter **Printing Defaults** des Druckers zur Verfügung.

### Modus `cups`

Weboberfläche öffnen, **Administration → Add Printer**, den Brother
MFC-260C (USB) und das Modell „Brother MFC-260C CUPS v1.1“ wählen und
„Share This Printer“ aktivieren.

## Weboberfläche und Anmeldung

- **Seitenleiste von Home Assistant** (Ingress): Hier bist du in beiden Modi
  automatisch als Admin angemeldet – Home Assistant hat dich ja schon
  angemeldet.
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
| `log_level` | `debug`, `info`, `warning`, `error`. `debug` schreibt zusätzlich das Debug-Log des Brother-Treibers ins Add-on-Log. |

## Fehlersuche

- **Drucker wird nicht gefunden:** Ist er eingeschaltet und per USB verbunden?
  Auf dem Host zeigt `lsusb` die USB-ID des Druckers. Weicht sie von der im
  Add-on hinterlegten `04f9:01d6` ab, muss der USB-Quirk in
  `rootfs/usr/share/cups/usb/brother-mfc260c.usb-quirks` angepasst werden.
- **Druck kommt nicht oder fehlerhaft:** `log_level: debug` setzen, Add-on neu
  starten, erneut drucken und das Log ansehen.
- **Im Modus `printer_app` klappt es nicht:** `mode: cups` setzen, das Add-on
  neu starten und den Drucker dort einrichten.

## Umstieg von Version 1.x

Die Druckerkonfiguration liegt jetzt im Add-on-eigenen Speicher (`/data`,
in Backups enthalten) statt im Home-Assistant-Konfigurationsordner. Den
Drucker deshalb einmal neu einrichten (im Modus `printer_app` passiert das
automatisch). Der alte Ordner `cups/` im Home-Assistant-Konfigurationsordner
wird nicht mehr benutzt und kann gelöscht werden.
