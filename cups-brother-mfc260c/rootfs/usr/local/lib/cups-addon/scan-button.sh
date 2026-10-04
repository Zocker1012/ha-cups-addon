#!/bin/bash
# ==============================================================================
# Wird vom Brother Scan-Key-Tool aufgerufen, wenn am Gerät "Scan" gedrückt wird.
# Aufruf: scan-button.sh <ziel: file|image|ocr|email> <SANE-Gerät>
# Scannt mit den Einstellungen aus den Add-on-Optionen in den Scan-Ordner und
# meldet das Ergebnis als Ereignis "cups_addon_scan" an Home Assistant.
# ==============================================================================
set -u

target="${1:-file}"
device="${2:-}"

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

# Ohne Gerätenamen den ersten Brother-Scanner nehmen
if [[ -z "${device}" ]]; then
    device=$(scanimage -f '%d%n' 2>/dev/null | grep -m1 '^brother' || true)
fi
if [[ -z "${device}" ]]; then
    log "Kein Scanner gefunden"
    notify "error" ""
    exit 1
fi

# Passenden Farbmodus aus den vom Treiber angebotenen Modi wählen
# (brother2 z. B.: "Black & White|Gray[Error Diffusion]|True Gray|24bit Color")
mode=""
choices=$(scanimage -d "${device}" -A 2>/dev/null \
    | sed -n 's/^ *--mode \(.*\) \[.*$/\1/p' | head -n1 || true)
if [[ -n "${choices}" ]]; then
    IFS='|' read -ra available <<<"${choices}"
    if [[ "${SCAN_MODE}" == "gray" ]]; then
        preferred=("True Gray" "Gray" "Grayscale")
        pattern="Gray"
    else
        preferred=("24bit Color" "Color")
        pattern="Color"
    fi
    for want in "${preferred[@]}"; do
        for have in "${available[@]}"; do
            if [[ "${have}" == "${want}" ]]; then
                mode="${have}"
                break 2
            fi
        done
    done
    if [[ -z "${mode}" ]]; then
        for have in "${available[@]}"; do
            if [[ "${have}" == *"${pattern}"* ]]; then
                mode="${have}"
                break
            fi
        done
    fi
fi

case "${SCAN_FORMAT}" in
    jpeg) ext="jpg" ;;
    png) ext="png" ;;
    *) ext="pdf" ;;
esac

mkdir -p "${SCAN_FOLDER}"
name="scan_$(date +%Y-%m-%d_%H-%M-%S).${ext}"
tmp="${SCAN_FOLDER}/.${name}.part"
out="${SCAN_FOLDER}/${name}"

log "Scanne (${target}) von ${device}: ${SCAN_RESOLUTION} dpi, ${mode:-Standardmodus}, ${SCAN_FORMAT}"

args=(-d "${device}" --resolution "${SCAN_RESOLUTION}" --format="${SCAN_FORMAT}" -o "${tmp}")
if [[ -n "${mode}" ]]; then
    args+=(--mode "${mode}")
fi

if scanimage "${args[@]}" && [[ -s "${tmp}" ]]; then
    mv "${tmp}" "${out}"
    log "Gespeichert: ${out}"
    notify "ok" "${out}"
else
    rm -f "${tmp}"
    log "Scan fehlgeschlagen"
    notify "error" ""
    exit 1
fi
