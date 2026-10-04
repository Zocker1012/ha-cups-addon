#!/bin/bash
# ==============================================================================
# Wird vom Brother Scan-Key-Tool aufgerufen, wenn am Gerät im Menü "Scan" ein
# Ziel gewählt wird. Aufruf: scan-button.sh <ziel: file|image|ocr|email> [gerät]
#
# Gescannt wird über AirSane (eSCL auf 127.0.0.1:8090) – derselbe Weg wie in
# der Weboberfläche, der Scanner bleibt so in einer Hand. Das Ergebnis landet
# im Scan-Ordner; Home Assistant bekommt das Ereignis "cups_addon_scan".
# ==============================================================================
set -u

readonly ESCL="http://127.0.0.1:8090/eSCL"
target="${1:-file}"

# shellcheck source=/dev/null
source /run/cups-addon/scan.env

log() {
    { echo "[scan-button] $*" > /proc/1/fd/1; } 2>/dev/null || echo "[scan-button] $*"
}

notify() {
    local status="$1" file="$2"
    [[ -n "${SUPERVISOR_TOKEN:-}" ]] || return 0
    jq -n --arg s "${status}" --arg f "${file}" --arg t "${target}" \
        '{status: $s, file: $f, target: $t}' \
        | curl -s -o /dev/null --max-time 10 -X POST \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            --data-binary @- \
            "${SUPERVISOR_API:-http://supervisor}/core/api/events/cups_addon_scan" || true
}

fail() {
    log "Scan fehlgeschlagen: $*"
    notify "error" ""
    exit 1
}

# Menüpunkt "Bild" am Gerät: immer JPEG, Farbe aus eigener Einstellung
format="${SCAN_FORMAT}"
mode="${SCAN_MODE}"
if [[ "${target}" == "image" ]]; then
    format="jpeg"
    mode="${SCAN_IMAGE_MODE:-color}"
fi

case "${format}" in
    jpeg) mime="image/jpeg"; ext="jpg"; intent="Photo" ;;
    png) mime="image/png"; ext="png"; intent="Photo" ;;
    *) mime="application/pdf"; ext="pdf"; intent="Document" ;;
esac

if [[ "${mode}" == "gray" ]]; then
    color="Grayscale8"
else
    color="RGB24"
fi

mkdir -p "${SCAN_FOLDER}"

# Immer nur ein Scan zur Zeit (Menü am Gerät mehrfach gewählt)
exec 9> /run/cups-addon/scan-button.lock
flock 9

# Eindeutiger Dateiname, auch bei zwei Scans in derselben Sekunde
base="scan_$(date +%Y-%m-%d_%H-%M-%S)"
if compgen -G "${SCAN_FOLDER}/${base}*" > /dev/null; then
    base="${base}_$$"
fi
saved=()

# Warten, bis AirSane läuft und der Scanner frei ist (z. B. nach einem
# Neustart des Scanner-Dienstes oder direkt nach dem vorigen Scan)
wait_ready() {
    local i
    for i in $(seq 1 60); do
        if curl -s --max-time 5 "${ESCL}/ScannerStatus" \
            | grep -q '<pwg:State>Idle</pwg:State>'; then
            return 0
        fi
        [[ "${i}" -eq 1 ]] && log "Warte auf den Scanner ..."
        sleep 1
    done
    return 1
}

# Einen Scan-Auftrag über AirSane ausführen und alle Seiten speichern.
# $1: eSCL-Quelle (Platen = Vorlagenglas, Feeder = Vorlageneinzug)
scan_from() {
    local input="$1" extra="" settings job page name tmp status
    if [[ "${input}" == "Feeder" ]]; then
        # Mehrere Seiten möglichst in einer Datei (PDF)
        extra="<scan:ConcatIfPossible>1</scan:ConcatIfPossible>"
    fi

    settings="<?xml version='1.0' encoding='UTF-8'?>
<scan:ScanSettings xmlns:scan='http://schemas.hp.com/imaging/escl/2011/05/03' xmlns:pwg='http://www.pwg.org/schemas/2010/12/sm'>
  <pwg:Version>2.6</pwg:Version>
  <scan:Intent>${intent}</scan:Intent>
  <pwg:InputSource>${input}</pwg:InputSource>
  ${extra}
  <scan:ColorMode>${color}</scan:ColorMode>
  <scan:XResolution>${SCAN_RESOLUTION}</scan:XResolution>
  <scan:YResolution>${SCAN_RESOLUTION}</scan:YResolution>
  <pwg:DocumentFormat>${mime}</pwg:DocumentFormat>
</scan:ScanSettings>"

    log "Scanne (${target}): ${SCAN_RESOLUTION} dpi, ${mode}, ${format}, Quelle ${input}"

    # Scan-Auftrag anlegen; die Antwort enthält den Auftragspfad im Location-Header
    job=$(curl -s --max-time 30 -D - -o /dev/null -X POST \
            -H "Content-Type: text/xml" --data-binary "${settings}" \
            "${ESCL}/ScanJobs" \
        | tr -d '\r' | sed -n 's/^[Ll]ocation: *//p' | head -n1) || job=""
    if [[ -z "${job}" ]]; then
        log "Scanner nicht erreichbar oder Auftrag abgelehnt (Quelle ${input})"
        return 1
    fi
    job="${job#http://*/}"
    job="/${job#/}"

    page=1
    while true; do
        if [[ "${#saved[@]}" -eq 0 ]]; then
            name="${base}.${ext}"
        else
            name="${base}_$(( ${#saved[@]} + 1 )).${ext}"
        fi
        tmp="${SCAN_FOLDER}/.${name}.part"

        status=$(curl -s --max-time 600 -o "${tmp}" -w '%{http_code}' \
            "http://127.0.0.1:8090${job}/NextDocument") || status="000"

        if [[ "${status}" == "200" && -s "${tmp}" ]]; then
            mv "${tmp}" "${SCAN_FOLDER}/${name}"
            saved+=("${SCAN_FOLDER}/${name}")
            log "Gespeichert: ${SCAN_FOLDER}/${name}"
            page=$((page + 1))
            continue
        fi

        rm -f "${tmp}"
        # 404 = keine weiteren Seiten
        if [[ "${status}" != "404" ]]; then
            log "Antwort des Scanners: HTTP ${status} (Quelle ${input})"
        fi
        break
    done

    [[ "${page}" -gt 1 ]]
}

wait_ready || fail "Scanner nicht bereit (läuft der Scanner-Dienst? Zeigt das Gerät \"PC-Anschluss\", dort Stopp drücken)"

# Die Quelle wählt der MFC-260C selbst: Liegt Papier im Einzug, scannt er von
# dort, sonst vom Vorlagenglas. "Feeder" sorgt nur dafür, dass alle Seiten aus
# dem Einzug abgeholt werden – beim Vorlagenglas endet der Auftrag nach einer
# Seite. Mit "Platen" bliebe das Gerät bei weiteren Seiten im Einzug hängen.
scan_from Feeder || { wait_ready && scan_from Platen; }

[[ "${#saved[@]}" -gt 0 ]] || fail "keine Daten vom Scanner erhalten"

for file in "${saved[@]}"; do
    notify "ok" "${file}"
done
