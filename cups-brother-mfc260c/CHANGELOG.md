# Changelog

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
