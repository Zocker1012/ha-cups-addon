#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Automatische Einrichtung des Brother MFC-260C in der Legacy Printer Application
# Läuft im Hintergrund, sobald der Server erreichbar ist.
# ==============================================================================

readonly APP="legacy-printer-app"
readonly SOCKET="/run/legacy-printer-app.sock"
readonly PRINTER_NAME="MFC260C"
readonly MODEL_PATTERN="mfc-?260c"

# ------------------------------------------------------------------------------
# Warten, bis der Server fertig gestartet ist und Anfragen beantwortet.
# Wichtig: Die CLI darf erst laufen, wenn der Domain-Socket existiert –
# sonst startet sie einen eigenen privaten Server.
# ------------------------------------------------------------------------------
wait_for_server() {
    local tries=0

    until [[ -S "${SOCKET}" ]] && printers=$("${APP}" printers 2>/dev/null); do
        tries=$((tries + 1))
        if [[ "${tries}" -ge 60 ]]; then
            bashio::log.warning "Auto-Einrichtung: Server nicht erreichbar – abgebrochen"
            exit 0
        fi
        sleep 2
    done
}

printers=""
wait_for_server

if [[ -n "${printers}" ]]; then
    bashio::log.info "Auto-Einrichtung: Drucker bereits vorhanden – nichts zu tun"
    exit 0
fi

bashio::log.info "Auto-Einrichtung: Suche Brother MFC-260C..."

driver=$("${APP}" drivers 2>/dev/null \
    | grep -iE "${MODEL_PATTERN}" \
    | head -n1 \
    | cut -d' ' -f1) || true

if [[ -z "${driver}" ]]; then
    bashio::log.error "Auto-Einrichtung: Brother-Treiber nicht gefunden"
    exit 0
fi

# Geräteliste: URI ohne Einrückung, Details (Info, Geräte-ID) eingerückt darunter
device_uri=$("${APP}" devices -o verbose 2>/dev/null \
    | awk -v pattern="${MODEL_PATTERN}" '
        /^[^ \t]/ { uri = $1 }
        tolower($0) ~ pattern && uri != "" { print uri }
    ' \
    | awk '/usb/ { print; found = 1; exit } { first = first ? first : $0 } END { if (!found && first) print first }') || true

if [[ -z "${device_uri}" ]]; then
    bashio::log.warning "Auto-Einrichtung: Brother MFC-260C nicht gefunden (eingeschaltet und per USB verbunden?). Neuer Versuch beim nächsten Start."
    exit 0
fi

bashio::log.info "Auto-Einrichtung: Lege Drucker '${PRINTER_NAME}' an (${device_uri}, Treiber ${driver})"

if "${APP}" add -d "${PRINTER_NAME}" -m "${driver}" -v "${device_uri}"; then
    "${APP}" default -d "${PRINTER_NAME}" || true
    bashio::log.info "Auto-Einrichtung: Drucker '${PRINTER_NAME}' ist eingerichtet"
else
    bashio::log.error "Auto-Einrichtung: Anlegen des Druckers fehlgeschlagen"
fi
