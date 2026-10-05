#!/command/with-contenv bashio
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Drucker beobachten (beide Modi): Ein/Aus am USB und wartende Aufträge
#
# - Log-Meldung, wenn der Drucker aus- oder eingeschaltet wird und wenn ein
#   Auftrag auf den ausgeschalteten Drucker wartet. Die Warteschlange bleibt in
#   beiden Modi bestehen; nach dem Einschalten wird gedruckt.
# - Ereignis "cups_addon_printer" an Home Assistant, z. B. um eine
#   schaltbare Steckdose ein- und wieder auszuschalten:
#     job_queued   ein Auftrag ist angekommen (vorher war keiner da)
#     jobs_done    alle Aufträge sind erledigt
#     printer_on   Drucker eingeschaltet / per USB verbunden
#     printer_off  Drucker ausgeschaltet / USB getrennt
# - Mit MQTT: Zustand für die Entitäten des Geräts "Brother MFC-260C".
# Abgefragt wird alle paar Sekunden: Dateien im USB-Verzeichnis des Systems
# und eine lokale IPP-Anfrage – kaum Last, kein Netzwerkverkehr nach außen.
# ==============================================================================

MODE=$(bashio::config 'printer.mode')
readonly MODE
readonly BROTHER_VENDOR_ID="04f9"
readonly USB_SYSFS="${USB_SYSFS:-/sys/bus/usb/devices}"
readonly STATE_TEST="/usr/share/cups-addon/ipptool/printer-state.test"
readonly INTERVAL=5

# shellcheck source=../../../usr/local/lib/cups-addon/mqtt.sh
source /usr/local/lib/cups-addon/mqtt.sh

# Ist ein Brother-Gerät am USB? (true/false, "unknown" ohne Zugriff)
usb_state() {
    local dev
    [[ -d "${USB_SYSFS}" ]] || { echo "unknown"; return; }
    for dev in "${USB_SYSFS}"/*; do
        [[ -r "${dev}/idVendor" ]] || continue
        if [[ "$(<"${dev}/idVendor")" == "${BROTHER_VENDOR_ID}" ]]; then
            echo "true"
            return
        fi
    done
    echo "false"
}

# Adresse des (Standard-)Druckers für IPP-Anfragen, leer wenn keiner da ist
printer_uri() {
    local name
    if [[ "${MODE}" == "cups" ]]; then
        name=$(LC_ALL=C lpstat -d 2> /dev/null | sed -n 's/^system default destination: //p' || true)
        [[ -n "${name}" ]] || name=$(LC_ALL=C lpstat -p 2> /dev/null | awk '$1 == "printer" {print $2; exit}' || true)
        [[ -z "${name}" ]] || echo "ipp://localhost:631/printers/${name}"
    else
        echo "ipp://localhost:631/ipp/print"
    fi
}

# Zahl der wartenden Aufträge (leer, wenn der Drucker nicht abfragbar ist)
queued_jobs() {
    local uri
    uri=$(printer_uri)
    [[ -n "${uri}" ]] || return 0
    # Solange der Server startet, schlägt die Abfrage fehl – kein Fehler
    ipptool -t "${uri}" "${STATE_TEST}" 2> /dev/null \
        | sed -n 's/.*queued-job-count (integer) = \([0-9]*\).*/\1/p' | head -n1 || true
}

# Ereignis an Home Assistant
notify() {
    local status="$1" jobs="$2" on="$3"
    [[ -n "${SUPERVISOR_TOKEN:-}" ]] || return 0
    jq -n --arg s "${status}" --argjson j "${jobs:-0}" --arg o "${on}" \
        '{status: $s, jobs: $j, printer_on: ($o == "true")}' \
        | curl -s -o /dev/null --max-time 10 -X POST \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            --data-binary @- \
            "${SUPERVISOR_API:-http://supervisor}/core/api/events/cups_addon_printer" || true
}

# Zustand für die MQTT-Entitäten, nur bei Änderungen senden
published=""
publish_state() {
    local power status payload
    case "${on}" in
        true) power="ON" ;;
        false) power="OFF" ;;
        *) power="None" ;;
    esac
    if [[ "${jobs}" -gt 0 && "${on}" == "false" ]]; then
        status="Wartet auf Drucker"
    elif [[ "${jobs}" -gt 0 ]]; then
        status="Druckt"
    elif [[ "${on}" == "false" ]]; then
        status="Aus"
    else
        status="Bereit"
    fi
    payload=$(jq -cn --arg p "${power}" --argjson j "${jobs}" --arg s "${status}" --arg m "${MODE}" \
        '{power: $p, jobs: $j, status: $s, mode: $m}')
    if [[ "${payload}" != "${published}" ]]; then
        mqtt_pub "${MQTT_BASE}/state" "${payload}"
        published="${payload}"
    fi
}

# Ausgangslage melden, aber kein Ereignis auslösen
on=$(usb_state)
case "${on}" in
    true) bashio::log.info "Drucker ist eingeschaltet (USB verbunden)" ;;
    false) bashio::log.info "Drucker ist ausgeschaltet oder nicht per USB verbunden" ;;
    *) bashio::log.warning "Drucker-Überwachung: USB-Bus nicht lesbar – Ein/Aus wird nicht gemeldet" ;;
esac
jobs=$(queued_jobs)
jobs="${jobs:-0}"
waiting_reported=false
mqtt_pub "${MQTT_BASE}/availability" "online"
publish_state

while true; do
    sleep "${INTERVAL}"

    new_on=$(usb_state)
    if [[ "${new_on}" != "${on}" && "${on}" != "unknown" ]]; then
        if [[ "${new_on}" == "true" ]]; then
            bashio::log.info "Drucker eingeschaltet (USB verbunden)"
            notify printer_on "${jobs}" true
        else
            bashio::log.info "Drucker ausgeschaltet oder USB getrennt – Aufträge werden gesammelt"
            notify printer_off "${jobs}" false
        fi
        waiting_reported=false
    fi
    on="${new_on}"

    new_jobs=$(queued_jobs)
    # Nicht abfragbar (z. B. Server startet neu): letzten Stand behalten
    new_jobs="${new_jobs:-${jobs}}"
    if [[ "${new_jobs}" -gt 0 && "${jobs}" -eq 0 ]]; then
        notify job_queued "${new_jobs}" "${on}"
    elif [[ "${new_jobs}" -eq 0 && "${jobs}" -gt 0 ]]; then
        notify jobs_done 0 "${on}"
        waiting_reported=false
    fi
    if [[ "${new_jobs}" -gt 0 && "${on}" == "false" && "${waiting_reported}" != "true" ]]; then
        bashio::log.info "Druckauftrag wartet – der Drucker ist ausgeschaltet. Nach dem Einschalten wird gedruckt."
        waiting_reported=true
    fi
    jobs="${new_jobs}"
    publish_state
done
