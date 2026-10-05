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
# PDF. Qualität: PDF und PNG verlustfrei, JPEG Qualität 90; nur "Verkleinern"
# speichert die Seiten als JPEG mit Qualität 75. Texterkennung fügt lediglich
# eine unsichtbare Textebene (PDF) bzw. eine .txt-Datei hinzu. Das Ergebnis
# landet im Scan-Ordner; Home Assistant bekommt das Ereignis "cups_addon_scan".
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
    ocr) prefix="SCAN_TEXT"; label="Text" ;;
    email) prefix="SCAN_EMAIL"; label="E-Mail" ;;
    *) prefix="SCAN_FILE"; label="Datei" ;;
esac
var="${prefix}_FORMAT" && format="${!var:-pdf}"
var="${prefix}_MODE" && mode="${!var:-color}"
var="${prefix}_RESOLUTION" && resolution="${!var:-300}"

# Texterkennung, wenn für den Menüpunkt eingeschaltet (nicht bei "Bild")
ocr=false
var="${prefix}_OCR"
if [[ "${target}" != "image" && "${!var:-false}" == "true" ]]; then
    ocr=true
fi

# Verkleinern (PDF und JPEG): Seiten als JPEG mit Qualität 75 statt
# verlustfrei (PDF) bzw. Qualität 90 (JPEG), Auflösung bleibt gleich
compress=false
var="${prefix}_COMPRESS"
if [[ "${!var:-false}" == "true" ]]; then
    if [[ "${format}" == "png" ]]; then
        log "Hinweis: Verkleinern hat bei PNG keine Wirkung (PNG ist immer verlustfrei)"
    else
        compress=true
    fi
fi
jpeg_quality=90
[[ "${compress}" == "true" ]] && jpeg_quality=75

case "${format}" in
    jpeg | png) ;;
    *) format="pdf" ;;
esac

if [[ "${mode}" == "gray" ]]; then
    color="Grayscale8"
else
    color="RGB24"
fi

# Auf Wunsch je Menüpunkt ein Unterordner (Datei, Bild, Text, E-Mail)
if [[ "${SCAN_SUBFOLDERS:-true}" == "true" ]]; then
    SCAN_FOLDER="${SCAN_FOLDER}/${label}"
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

# Arbeitsordner für Zwischenschritte (wird am Ende gelöscht). Der Scan selbst
# landet als .part-Datei im Scan-Ordner – so sieht man, dass er läuft.
work_dir=$(mktemp -d /tmp/scan.XXXXXX)
trap 'rm -rf "${work_dir}"; rm -f "${SCAN_FOLDER}/.${base}"_*.pdf.part' EXIT
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

# Einen Scan-Auftrag über AirSane ausführen und die PDF-Dokumente als
# .part-Dateien im Scan-Ordner ablegen. $1: eSCL-Quelle (Platen = Vorlagenglas, Feeder = Einzug)
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

    log "Scanne (${label}): ${resolution} dpi, ${mode}, ${format}$([[ "${ocr}" == "true" ]] && echo ", Texterkennung")$([[ "${compress}" == "true" ]] && echo ", verkleinert"), Quelle ${input}"

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
        file="${SCAN_FOLDER}/.${base}_$(( ${#scanned[@]} + 1 )).pdf.part"
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

# 1. Alle Dokumente des Scans zu einem PDF zusammenfassen (meist nur eins)
raw="${scanned[0]}"
if [[ "${#scanned[@]}" -gt 1 ]]; then
    qpdf --empty --pages "${scanned[@]}" -- "${work_dir}/raw.pdf" \
        || fail "Zusammenfassen der Seiten fehlgeschlagen"
    raw="${work_dir}/raw.pdf"
fi

# 1b. Leere Seiten entfernen (nur bei mehreren Seiten, nie alle). Eine Seite
#     gilt nur dann als leer, wenn sie praktisch keine dunklen Pixel hat –
#     schon ein kurzes Wort oder eine Seitenzahl reicht, damit sie bleibt.
if [[ "${SCAN_REMOVE_BLANK:-false}" == "true" ]]; then
    count=$(qpdf --show-npages "${raw}" 2> /dev/null || echo 0)
    if [[ "${count}" -gt 1 ]]; then
        nice -n 10 gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pgmraw -r150 \
            -sOutputFile="${work_dir}/blank_%04d.pgm" "${raw}" > /dev/null 2>&1
        # Ausgabe: "keep 1,3,4" und "blank 2"
        result=$(python3 - "${work_dir}" "${count}" <<'PY'
import re, sys
work, count = sys.argv[1], int(sys.argv[2])
keep, blank = [], []
for n in range(1, count + 1):
    try:
        d = open(f"{work}/blank_{n:04d}.pgm", "rb").read()
        m = re.match(rb"P5\s+(?:#[^\n]*\n\s*)*(\d+)\s+(\d+)\s+(\d+)\s", d)
        w, h = int(m.group(1)), int(m.group(2))
        px = d[m.end():]
    except Exception:
        keep.append(n)  # im Zweifel behalten
        continue
    # Ränder (2 %) ignorieren: dort liegen oft Schatten vom Scanner
    mx, my = w // 50, h // 50
    dark = 0
    dark_values = bytes(range(160))
    for y in range(my, h - my):
        row = px[y * w + mx:(y + 1) * w - mx]
        dark += len(row) - len(row.translate(None, dark_values))
    # Bei 150 dpi hat schon "Seite 3" in 10 pt rund 100 dunkle Pixel, eine
    # leere Seite mit Staubkorn nur wenige – im Zweifel bleibt die Seite.
    (blank if dark <= 20 else keep).append(n)
if not keep:  # nie alle Seiten entfernen
    keep, blank = blank, []
print("keep " + ",".join(map(str, keep)))
print("blank " + ",".join(map(str, blank)))
PY
        ) || result=""
        keep=$(sed -n 's/^keep //p' <<< "${result}")
        blank=$(sed -n 's/^blank //p' <<< "${result}")
        if [[ -n "${blank}" && -n "${keep}" ]] \
            && qpdf "${raw}" --pages "${raw}" "${keep}" -- "${work_dir}/noblank.pdf"; then
            raw="${work_dir}/noblank.pdf"
            log "Leere Seite(n) entfernt: ${blank//,/, }"
        fi
    fi
fi

# 2. Bei Texterkennung verkehrt herum oder quer liegende Seiten erkennen und
#    verlustfrei drehen (Seitenattribut im PDF, die Pixel bleiben unverändert).
#    Die Lageerkennung braucht etwa 300 dpi; gedreht wird nur bei
#    ausreichender Sicherheit.
if [[ "${ocr}" == "true" && "${SCAN_OCR_ROTATE:-true}" == "true" ]]; then
    rotations=()
    nice -n 10 gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=jpeggray -r300 \
        -sOutputFile="${work_dir}/osd_%04d.jpg" "${raw}" > /dev/null 2>&1
    n=1
    while [[ -f "$(printf '%s/osd_%04d.jpg' "${work_dir}" "${n}")" ]]; do
        osd=$(nice -n 10 tesseract "$(printf '%s/osd_%04d.jpg' "${work_dir}" "${n}")" - --psm 0 2> /dev/null) || osd=""
        angle=$(sed -n 's/^Rotate: *//p' <<< "${osd}")
        confidence=$(sed -n 's/^Orientation confidence: *//p' <<< "${osd}")
        if [[ -n "${angle}" && "${angle}" != "0" ]] \
            && awk -v c="${confidence:-0}" 'BEGIN { exit !(c >= 2) }'; then
            rotations+=("--rotate=+${angle}:${n}")
            log "Seite ${n} wird um ${angle}° gedreht"
        fi
        n=$((n + 1))
    done
    if [[ "${#rotations[@]}" -gt 0 ]] \
        && qpdf "${raw}" "${rotations[@]}" "${work_dir}/rotated.pdf"; then
        raw="${work_dir}/rotated.pdf"
    fi
fi

# 3. Seitenbilder in der Scan-Auflösung erzeugen: verlustfrei als PNG, als
#    JPEG mit Qualität 90 bzw. 75 (Verkleinern). Für PDF dienen sie als Seiten.
if [[ "${format}" == "png" || ( "${format}" == "pdf" && "${compress}" != "true" ) ]]; then
    kind="png"
else
    kind="jpeg"
fi
case "${kind}:${mode}" in
    png:gray) device="pnggray"; ext="png" ;;
    png:*) device="png16m"; ext="png" ;;
    jpeg:gray) device="jpeggray"; ext="jpg" ;;
    *) device="jpeg"; ext="jpg" ;;
esac
nice -n 10 gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE="${device}" \
    -dJPEGQ="${jpeg_quality}" -r"${resolution}" \
    -sOutputFile="${work_dir}/page_%04d.${ext}" "${raw}" > /dev/null 2>&1
mapfile -t pages < <(compgen -G "${work_dir}/page_*.${ext}" | sort)
[[ "${#pages[@]}" -gt 0 ]] || fail "Umwandlung der Seiten fehlgeschlagen"

# Verkleinern: JPEG-Seiten zusätzlich verlustfrei optimieren
if [[ "${compress}" == "true" && "${kind}" == "jpeg" ]]; then
    for page in "${pages[@]}"; do
        jpegtran -copy all -optimize -outfile "${page}.opt" "${page}" \
            && mv "${page}.opt" "${page}"
    done
fi

# 4. Texterkennung: unsichtbare Textebene als eigenes PDF und Text als .txt
if [[ "${ocr}" == "true" ]]; then
    case "${SCAN_OCR_LANG:-deu_eng}" in
        deu) lang="deu" ;;
        eng) lang="eng" ;;
        *) lang="deu+eng" ;;
    esac
    log "Texterkennung (${lang}) für ${#pages[@]} Seite(n) ..."
    printf '%s\n' "${pages[@]}" > "${work_dir}/pages.txt"
    nice -n 10 tesseract "${work_dir}/pages.txt" "${work_dir}/text" \
        -l "${lang}" -c textonly_pdf=1 pdf txt > /dev/null 2>&1 \
        || fail "Texterkennung fehlgeschlagen"
fi

# 5. Ergebnis speichern
if [[ "${format}" == "pdf" ]]; then
    # Seitenbilder unverändert ins PDF übernehmen (PNG verlustfrei, JPEG wie
    # erzeugt), bei Texterkennung die Textebene darüberlegen
    img2pdf "${pages[@]}" -o "${work_dir}/pages.pdf" > /dev/null 2>&1 \
        || fail "PDF konnte nicht erstellt werden"
    result="${work_dir}/pages.pdf"
    if [[ "${ocr}" == "true" ]]; then
        qpdf "${result}" --overlay "${work_dir}/text.pdf" -- "${work_dir}/result.pdf" \
            || fail "Textebene konnte nicht eingefügt werden"
        result="${work_dir}/result.pdf"
    fi
    file=$(publish "${result}" "${base}.pdf") && saved+=("${file}")
else
    n=1
    for page in "${pages[@]}"; do
        file=$(publish "${page}" "$(name_for "${n}" "${ext}")") && saved+=("${file}")
        n=$((n + 1))
    done
    if [[ "${ocr}" == "true" ]]; then
        file=$(publish "${work_dir}/text.txt" "${base}.txt") && saved+=("${file}")
    fi
fi

[[ "${#saved[@]}" -gt 0 ]] || fail "Scan konnte nicht gespeichert werden"
for file in "${saved[@]}"; do
    log "Gespeichert: ${file}"
done

for file in "${saved[@]}"; do
    notify "ok" "${file}"
done
