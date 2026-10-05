#!/bin/bash
# ==============================================================================
# Wird vom Brother Scan-Key-Tool aufgerufen, wenn am Gerät im Menü "Scan" ein
# Ziel gewählt wird. Aufruf: scan-button.sh <ziel: file|image|ocr|email> [gerät]
#
# Gescannt wird über AirSane (eSCL auf 127.0.0.1:8090) – derselbe Weg wie in
# der Weboberfläche, der Scanner bleibt so in einer Hand. Angefordert wird
# immer ein PDF mit allen Seiten in einem Durchgang: Nur dieser Weg läuft am
# MFC-260C zuverlässig (Seite für Seite als Bild bleibt das Gerät bei
# "PC-Anschluss" hängen). JPEG/PNG und Texterkennung entstehen danach aus dem
# PDF (Ghostscript, Tesseract). Das Ergebnis landet im Scan-Ordner; Home
# Assistant bekommt das Ereignis "cups_addon_scan".
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

# Jeder Menüpunkt hat eigene Einstellungen. Brothers Scan-Key-Tool meldet
# die Menüpunkte des MFC-260C als file (Datei), image (Bild), ocr (Text) und
# email (E-Mail).
case "${target}" in
    image) prefix="SCAN_IMAGE"; label="Bild" ;;
    ocr) prefix="SCAN_OCR"; label="Text" ;;
    email) prefix="SCAN_EMAIL"; label="E-Mail" ;;
    *) prefix="SCAN_FILE"; label="Datei" ;;
esac
var="${prefix}_FORMAT" && format="${!var:-pdf}"
var="${prefix}_MODE" && mode="${!var:-color}"
var="${prefix}_RESOLUTION" && resolution="${!var:-300}"

# Texterkennung nur beim Menüpunkt "Text" und wenn eingeschaltet
ocr=false
if [[ "${target}" == "ocr" && "${SCAN_OCR_TEXT:-false}" == "true" ]]; then
    ocr=true
fi

case "${format}" in
    jpeg | png) ;;
    *) format="pdf" ;;
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

# Arbeitsordner für den Scan und Zwischenschritte (wird am Ende gelöscht)
work_dir=$(mktemp -d /tmp/scan.XXXXXX)
trap 'rm -rf "${work_dir}"' EXIT
scanned=()
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

# Einen Scan-Auftrag über AirSane ausführen und die PDF-Dokumente im
# Arbeitsordner ablegen. $1: eSCL-Quelle (Platen = Vorlagenglas, Feeder = Einzug)
scan_from() {
    local input="$1" extra="" settings job file status
    if [[ "${input}" == "Feeder" ]]; then
        # Alle Seiten aus dem Einzug in einem Durchgang und einer Datei
        extra="<scan:ConcatIfPossible>1</scan:ConcatIfPossible>"
    fi

    settings="<?xml version='1.0' encoding='UTF-8'?>
<scan:ScanSettings xmlns:scan='http://schemas.hp.com/imaging/escl/2011/05/03' xmlns:pwg='http://www.pwg.org/schemas/2010/12/sm'>
  <pwg:Version>2.6</pwg:Version>
  <scan:Intent>Document</scan:Intent>
  <pwg:InputSource>${input}</pwg:InputSource>
  ${extra}
  <scan:ColorMode>${color}</scan:ColorMode>
  <scan:XResolution>${resolution}</scan:XResolution>
  <scan:YResolution>${resolution}</scan:YResolution>
  <pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>
</scan:ScanSettings>"

    log "Scanne (${label}): ${resolution} dpi, ${mode}, ${format}$([[ "${ocr}" == "true" ]] && echo ", Texterkennung"), Quelle ${input}"

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

    while true; do
        file="${work_dir}/scan_$(( ${#scanned[@]} + 1 )).pdf"
        status=$(curl -s --max-time 900 -o "${file}" -w '%{http_code}' \
            "http://127.0.0.1:8090${job}/NextDocument") || status="000"

        if [[ "${status}" == "200" && -s "${file}" ]]; then
            scanned+=("${file}")
            continue
        fi

        rm -f "${file}"
        # 404 = keine weiteren Seiten
        if [[ "${status}" != "404" ]]; then
            log "Antwort des Scanners: HTTP ${status} (Quelle ${input})"
        fi
        break
    done

    [[ "${#scanned[@]}" -gt 0 ]]
}

wait_ready || fail "Scanner nicht bereit (läuft der Scanner-Dienst? Zeigt das Gerät \"PC-Anschluss\", dort Stopp drücken)"

# Die Quelle wählt der MFC-260C selbst: Liegt Papier im Einzug, scannt er von
# dort, sonst vom Vorlagenglas. "Feeder" sorgt nur dafür, dass alle Seiten aus
# dem Einzug abgeholt werden – beim Vorlagenglas endet der Auftrag nach einer
# Seite. Mit "Platen" bliebe das Gerät bei weiteren Seiten im Einzug hängen.
scan_from Feeder || { wait_ready && scan_from Platen; }

[[ "${#scanned[@]}" -gt 0 ]] || fail "keine Daten vom Scanner erhalten"

# ------------------------------------------------------------------------------
# Ergebnis erzeugen
# ------------------------------------------------------------------------------

# Datei über eine .part-Datei in den Scan-Ordner kopieren (Ordner liegt evtl.
# auf einem anderen Dateisystem) und den Zielpfad ausgeben
publish() {
    local src="$1" name="$2"
    cp "${src}" "${SCAN_FOLDER}/.${name}.part" \
        && mv "${SCAN_FOLDER}/.${name}.part" "${SCAN_FOLDER}/${name}" \
        && echo "${SCAN_FOLDER}/${name}"
}

# Name der n-ten Datei: scan_<zeit>.<ext>, scan_<zeit>_2.<ext>, ...
name_for() {
    if [[ "$1" -eq 1 ]]; then
        echo "${base}.$2"
    else
        echo "${base}_$1.$2"
    fi
}

# Alle Seiten der gescannten PDFs als Bilder (Seite für Seite) ausgeben
# $1: jpeg | png – die Auflösung entspricht der Scan-Auflösung
render_pages() {
    local kind="$1" device ext
    case "${kind}:${mode}" in
        png:gray) device="pnggray"; ext="png" ;;
        png:*) device="png16m"; ext="png" ;;
        jpeg:gray) device="jpeggray"; ext="jpg" ;;
        *) device="jpeg"; ext="jpg" ;;
    esac
    nice -n 10 gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE="${device}" \
        -dJPEGQ=90 -r"${resolution}" \
        -sOutputFile="${work_dir}/page_%04d.${ext}" "${scanned[@]}" > /dev/null 2>&1 \
        || return 1
    compgen -G "${work_dir}/page_*.${ext}"
}

# Verkehrt herum oder quer liegende Seite drehen (nur JPEG, verlustfrei).
# Tesseract meldet "Rotate: <Grad im Uhrzeigersinn>"; gedreht wird nur bei
# ausreichender Sicherheit, sonst bleibt die Seite wie gescannt.
rotate_page() {
    local page="$1" osd angle confidence
    osd=$(nice -n 10 tesseract "${page}" - --psm 0 2> /dev/null) || return 0
    angle=$(sed -n 's/^Rotate: *//p' <<< "${osd}")
    confidence=$(sed -n 's/^Orientation confidence: *//p' <<< "${osd}")
    [[ -n "${angle}" && "${angle}" != "0" ]] || return 0
    if awk -v c="${confidence:-0}" 'BEGIN { exit !(c >= 2) }'; then
        jpegtran -copy all -rotate "${angle}" -outfile "${page}.rot" "${page}" \
            && mv "${page}.rot" "${page}" \
            && log "Seite ${page##*/} um ${angle}° gedreht"
    fi
}

if [[ "${format}" == "pdf" && "${ocr}" != "true" ]]; then
    # PDF direkt übernehmen
    n=1
    for doc in "${scanned[@]}"; do
        file=$(publish "${doc}" "$(name_for "${n}" pdf)") && saved+=("${file}")
        n=$((n + 1))
    done
else
    # Seitenbilder erzeugen: für die Texterkennung mit PDF-Ziel als JPEG
    kind="${format}"
    [[ "${kind}" == "pdf" ]] && kind="jpeg"
    mapfile -t pages < <(render_pages "${kind}" | sort)
    [[ "${#pages[@]}" -gt 0 ]] || fail "Umwandlung der Seiten fehlgeschlagen"

    if [[ "${ocr}" == "true" ]]; then
        case "${SCAN_OCR_LANG:-deu_eng}" in
            deu) lang="deu" ;;
            eng) lang="eng" ;;
            *) lang="deu+eng" ;;
        esac
        log "Texterkennung (${lang}) für ${#pages[@]} Seite(n) ..."
        if [[ "${SCAN_OCR_ROTATE:-true}" == "true" && "${kind}" == "jpeg" ]]; then
            for page in "${pages[@]}"; do
                rotate_page "${page}"
            done
        fi
    fi

    if [[ "${format}" == "pdf" ]]; then
        # Alle Seiten in ein durchsuchbares PDF (Bild + unsichtbarer Text)
        printf '%s\n' "${pages[@]}" > "${work_dir}/pages.txt"
        if nice -n 10 tesseract "${work_dir}/pages.txt" "${work_dir}/${base}" \
                -l "${lang}" pdf > /dev/null 2>&1 \
            && file=$(publish "${work_dir}/${base}.pdf" "${base}.pdf"); then
            saved+=("${file}")
        else
            fail "Texterkennung fehlgeschlagen"
        fi
    else
        # Bilder; bei Texterkennung dazu der erkannte Text als .txt
        n=1
        for page in "${pages[@]}"; do
            file=$(publish "${page}" "$(name_for "${n}" "${page##*.}")") && saved+=("${file}")
            if [[ "${ocr}" == "true" ]]; then
                nice -n 10 tesseract "${page}" - -l "${lang}" 2> /dev/null >> "${work_dir}/${base}.txt"
                printf '\f' >> "${work_dir}/${base}.txt"
            fi
            n=$((n + 1))
        done
        if [[ "${ocr}" == "true" ]]; then
            file=$(publish "${work_dir}/${base}.txt" "${base}.txt") && saved+=("${file}")
        fi
    fi
fi

[[ "${#saved[@]}" -gt 0 ]] || fail "Scan konnte nicht gespeichert werden"
for file in "${saved[@]}"; do
    log "Gespeichert: ${file}"
done

for file in "${saved[@]}"; do
    notify "ok" "${file}"
done
