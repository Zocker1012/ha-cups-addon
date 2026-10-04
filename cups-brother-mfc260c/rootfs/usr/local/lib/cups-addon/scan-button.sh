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
    echo "[scan-button] $*" > /proc/1/fd/1 2>/dev/null || echo "[scan-button] $*"
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

# Menüpunkt "Bild" am Gerät: immer JPEG in Farbe, sonst die Einstellungen
format="${SCAN_FORMAT}"
mode="${SCAN_MODE}"
if [[ "${target}" == "image" ]]; then
    format="jpeg"
    mode="color"
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

settings="<?xml version='1.0' encoding='UTF-8'?>
<scan:ScanSettings xmlns:scan='http://schemas.hp.com/imaging/escl/2011/05/03' xmlns:pwg='http://www.pwg.org/schemas/2010/12/sm'>
  <pwg:Version>2.6</pwg:Version>
  <scan:Intent>${intent}</scan:Intent>
  <pwg:InputSource>Platen</pwg:InputSource>
  <scan:ColorMode>${color}</scan:ColorMode>
  <scan:XResolution>${SCAN_RESOLUTION}</scan:XResolution>
  <scan:YResolution>${SCAN_RESOLUTION}</scan:YResolution>
  <pwg:DocumentFormat>${mime}</pwg:DocumentFormat>
</scan:ScanSettings>"

log "Scanne (${target}): ${SCAN_RESOLUTION} dpi, ${mode}, ${format}"

# Scan-Auftrag anlegen; die Antwort enthält den Auftragspfad im Location-Header
job=$(curl -s --max-time 30 -D - -o /dev/null -X POST \
        -H "Content-Type: text/xml" --data-binary "${settings}" \
        "${ESCL}/ScanJobs" \
    | tr -d '\r' | sed -n 's/^[Ll]ocation: *//p' | head -n1) || job=""
[[ -n "${job}" ]] || fail "Scanner nicht erreichbar oder Auftrag abgelehnt (läuft der Scanner-Dienst?)"
job="${job#http://*/}"
job="/${job#/}"

mkdir -p "${SCAN_FOLDER}"
base="scan_$(date +%Y-%m-%d_%H-%M-%S)"
saved=()
page=1
while true; do
    if [[ "${page}" -eq 1 ]]; then
        name="${base}.${ext}"
    else
        name="${base}_${page}.${ext}"
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
        log "Unerwartete Antwort des Scanners: HTTP ${status}"
    fi
    break
done

[[ "${#saved[@]}" -gt 0 ]] || fail "keine Daten vom Scanner erhalten"

for file in "${saved[@]}"; do
    notify "ok" "${file}"
done
