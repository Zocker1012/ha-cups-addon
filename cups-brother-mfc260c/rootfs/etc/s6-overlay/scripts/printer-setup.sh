#!/command/with-contenv bashio
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Automatische Einrichtung des Brother MFC-260C in der Legacy Printer Application
#
# PAPPL (und damit CUPS 3) erkennt neu angesteckte USB-Drucker nur beim Start.
# Daher beobachtet dieser Dienst den USB-Bus (sysfs) und richtet den Drucker
# ein, sobald ein Brother-Gerät auftaucht. Ist ein Drucker eingerichtet, beendet
# sich der Dienst bis zum nächsten Start des Add-ons.
# ==============================================================================

# shellcheck source=printer-app-env.sh
source /etc/s6-overlay/scripts/printer-app-env.sh

readonly APP="legacy-printer-app"
readonly SOCKET="/run/legacy-printer-app.sock"
readonly PRINTER_NAME="MFC260C"
readonly MODEL_PATTERN="mfc-?260c"
readonly BROTHER_VENDOR_ID="04f9"
readonly USB_SYSFS="${USB_SYSFS:-/sys/bus/usb/devices}"
readonly POLL_INTERVAL=5
readonly MAX_TRIES=3
# Merker: Papier wurde einmal auf A4 gestellt (danach gilt die eigene Einstellung)
readonly A4_MARKER="${STATE_DIR:-/data/legacy-printer-app}/.media-a4"

# ------------------------------------------------------------------------------
# Warten, bis der Server fertig gestartet ist und Anfragen beantwortet.
# Wichtig: Die CLI darf erst laufen, wenn der Domain-Socket existiert –
# sonst startet sie einen eigenen privaten Server.
# ------------------------------------------------------------------------------
wait_for_server() {
    local tries=0

    until [[ -S "${SOCKET}" ]] && "${APP}" printers > /dev/null 2>&1; do
        tries=$((tries + 1))
        if [[ "${tries}" -ge 60 ]]; then
            bashio::log.warning "Auto-Einrichtung: Server nicht erreichbar"
            return 1
        fi
        sleep 2
    done
}

# Angeschlossene Brother-USB-Geräte (sysfs-Pfade), leer wenn keins da ist
brother_usb_devices() {
    local dev

    for dev in "${USB_SYSFS}"/*; do
        [[ -r "${dev}/idVendor" ]] || continue
        if [[ "$(<"${dev}/idVendor")" == "${BROTHER_VENDOR_ID}" ]]; then
            echo "${dev##*/}"
        fi
    done
}

# Drucker anlegen, falls noch keiner existiert.
# Rückgabe: 0 = erledigt (eingerichtet oder schon vorhanden), 1 = nochmal versuchen
setup_printer() {
    local printers driver device_uri

    printers=$("${APP}" printers 2>/dev/null) || return 1
    if [[ -n "${printers}" ]]; then
        return 0
    fi

    bashio::log.info "Auto-Einrichtung: Suche Brother MFC-260C..."

    driver=$("${APP}" drivers 2>/dev/null \
        | grep -iE "${MODEL_PATTERN}" \
        | head -n1 \
        | cut -d' ' -f1) || true

    if [[ -z "${driver}" ]]; then
        bashio::log.error "Auto-Einrichtung: Brother-Treiber nicht gefunden"
        return 0
    fi

    # Geräteliste: URI ohne Einrückung, Details (Info, Geräte-ID) eingerückt darunter
    device_uri=$("${APP}" devices -o verbose 2>/dev/null \
        | awk -v pattern="${MODEL_PATTERN}" '
            /^[^ \t]/ { uri = $1 }
            tolower($0) ~ pattern && uri != "" { print uri }
        ' \
        | awk '/usb/ { print; found = 1; exit } { first = first ? first : $0 } END { if (!found && first) print first }') || true

    if [[ -z "${device_uri}" ]]; then
        bashio::log.warning "Auto-Einrichtung: Brother MFC-260C nicht gefunden (eingeschaltet und per USB verbunden?)"
        return 1
    fi

    bashio::log.info "Auto-Einrichtung: Lege Drucker '${PRINTER_NAME}' an (${device_uri}, Treiber ${driver})"

    if "${APP}" add -d "${PRINTER_NAME}" -m "${driver}" -v "${device_uri}"; then
        "${APP}" default -d "${PRINTER_NAME}" || true
        set_a4_once
        bashio::log.info "Auto-Einrichtung: Drucker '${PRINTER_NAME}' ist eingerichtet"
        return 0
    fi

    bashio::log.error "Auto-Einrichtung: Anlegen des Druckers fehlgeschlagen"
    return 1
}

# Eingelegtes Papier und Standardformat einmalig auf A4 stellen. Die
# Brother-PPD gibt Letter vor – Aufträge ohne Formatangabe (z. B. aus dem
# Druckordner) würden sonst als Letter gedruckt.
set_a4_once() {
    local printer

    [[ -e "${A4_MARKER}" ]] && return 0
    while IFS= read -r printer; do
        [[ -n "${printer}" ]] || continue
        if "${APP}" options -d "${printer}" 2>/dev/null \
            | grep -q 'media=na_letter_8.5x11in .*(default)'; then
            if "${APP}" modify -d "${printer}" -o media-ready=iso_a4_210x297mm; then
                bashio::log.info "Auto-Einrichtung: Papierformat von '${printer}' auf A4 gestellt"
            fi
        fi
    done < <("${APP}" printers 2>/dev/null)
    touch "${A4_MARKER}"
}

# Fertig: Dienst nicht von s6 neu starten lassen
finish() {
    s6-svc -O . 2> /dev/null || true
    exit 0
}

wait_for_server || finish

if [[ -n "$("${APP}" printers 2>/dev/null)" ]]; then
    set_a4_once
    bashio::log.info "Auto-Einrichtung: Drucker bereits eingerichtet – keine USB-Überwachung nötig"
    finish
fi

# Ohne Zugriff auf den USB-Bus nur einmal beim Start einrichten
if [[ ! -d "${USB_SYSFS}" ]]; then
    bashio::log.warning "Auto-Einrichtung: USB-Bus nicht lesbar – neue Drucker werden nur beim Start erkannt"
    setup_printer || true
    finish
fi

bashio::log.info "Auto-Einrichtung: Überwache USB auf Brother-Drucker"

# Bei jeder Änderung der angeschlossenen Brother-Geräte (anstecken/einschalten)
# höchstens MAX_TRIES Einrichtungsversuche
known=""
tries=0
while true; do
    current=$(brother_usb_devices | sort | tr '\n' ' ')

    if [[ "${current}" != "${known}" ]]; then
        known="${current}"
        tries=0
        if [[ -n "${current}" ]]; then
            bashio::log.info "Auto-Einrichtung: Brother-USB-Gerät erkannt"
        fi
    fi

    if [[ -n "${current}" && "${tries}" -lt "${MAX_TRIES}" ]]; then
        if setup_printer; then
            bashio::log.info "Auto-Einrichtung: USB-Überwachung beendet"
            finish
        else
            tries=$((tries + 1))
        fi
    fi

    sleep "${POLL_INTERVAL}"
done
