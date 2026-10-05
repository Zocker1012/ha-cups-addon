#!/command/with-contenv bashio
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Druckordner: Neue Dateien automatisch drucken
# Eine Datei bleibt im Ordner, bis der Drucker mit ihr fertig ist, und wandert
# dann nach "gedruckt/" – abgebrochene oder fehlerhafte nach "fehler/".
# ==============================================================================

FOLDER=$(bashio::config 'folder_printing.path')
readonly FOLDER
readonly DONE_DIR="${FOLDER}/gedruckt"
readonly FAILED_DIR="${FOLDER}/fehler"
# Merker: Name der Datei, die gerade gedruckt wird (für einen Neustart)
readonly MARKER="${FOLDER}/.wird-gedruckt"
readonly STATE_TEST="/usr/share/cups-addon/ipptool/job-state.test"
MODE=$(bashio::config 'printer.mode')
readonly MODE
COLOR=$(bashio::config 'folder_printing.color' 'color')
readonly COLOR
QUALITY=$(bashio::config 'folder_printing.quality' 'normal')
readonly QUALITY
PAPER=$(bashio::config 'folder_printing.paper' 'a4')
readonly PAPER

# Papierformat: Name für die Printer Application (IPP) und für CUPS (PPD)
case "${PAPER}" in
    a5) MEDIA_IPP="iso_a5_148x210mm" MEDIA_PPD="A5" ;;
    a6) MEDIA_IPP="iso_a6_105x148mm" MEDIA_PPD="A6" ;;
    letter) MEDIA_IPP="na_letter_8.5x11in" MEDIA_PPD="Letter" ;;
    legal) MEDIA_IPP="na_legal_8.5x14in" MEDIA_PPD="Legal" ;;
    photo_10x15) MEDIA_IPP="na_index-4x6_4x6in" MEDIA_PPD="PostC4x6" ;;
    photo_13x18) MEDIA_IPP="na_5x7_5x7in" MEDIA_PPD="Photo2L" ;;
    photo_9x13) MEDIA_IPP="oe_photo-l_3.5x5in" MEDIA_PPD="PhotoL" ;;
    *) MEDIA_IPP="iso_a4_210x297mm" MEDIA_PPD="A4" ;;
esac
readonly MEDIA_IPP MEDIA_PPD

mkdir -p "${FOLDER}" "${DONE_DIR}" "${FAILED_DIR}"

# Standarddrucker bzw. ersten Drucker des aktiven Modus ermitteln
printer_name() {
    local name=""
    if [[ "${MODE}" == "cups" ]]; then
        name=$(LC_ALL=C lpstat -d 2>/dev/null | sed -n 's/^.*: //p')
        [[ -n "${name}" ]] || name=$(LC_ALL=C lpstat -p 2>/dev/null | awk '$1 == "printer" {print $2; exit}')
    else
        # shellcheck source=printer-app-env.sh
        source /etc/s6-overlay/scripts/printer-app-env.sh
        name=$(legacy-printer-app printers 2>/dev/null | head -n1)
    fi
    echo "${name}"
}

# Druckoptionen: Papierformat, Farbe und Qualität aus den Einstellungen
# (Modus "cups": PPD-Optionen des Brother-Treibers, sonst IPP-Attribute).
# Gibt die Auftragsnummer aus.
submit() {
    local file="$1" printer="$2" opts=() out
    if [[ "${MODE}" == "cups" ]]; then
        opts+=(-o "media=${MEDIA_PPD}")
        [[ "${COLOR}" == "gray" ]] && opts+=(-o BRMonoColor=BrMono)
        case "${QUALITY}" in
            draft) opts+=(-o Resolution=Draft) ;;
            fine) opts+=(-o Resolution=Fine) ;;
        esac
        # "request id is MFC260C-12 (1 file(s))"
        out=$(LC_ALL=C lp -d "${printer}" -t "${file##*/}" "${opts[@]}" -- "${file}") || return 1
        out="${out#request id is }"
        out="${out%% *}"
    else
        opts+=(-o "media=${MEDIA_IPP}")
        [[ "${COLOR}" == "gray" ]] && opts+=(-o print-color-mode=monochrome)
        case "${QUALITY}" in
            draft) opts+=(-o quality=fast) ;;
            fine) opts+=(-o quality=fine) ;;
        esac
        # "MFC260C-12"
        out=$(legacy-printer-app submit -d "${printer}" "${opts[@]}" "${file}") || return 1
    fi
    out="${out##*-}"
    [[ "${out}" =~ ^[0-9]+$ ]] || return 1
    echo "${out}"
}

# Warten, bis der Auftrag fertig ist. 0 = gedruckt, 1 = abgebrochen/Fehler
wait_for_job() {
    local printer="$1" job="$2" uri state waiting=false missing=0
    if [[ "${MODE}" == "cups" ]]; then
        uri="ipp://localhost:631/printers/${printer}"
    else
        uri="ipp://localhost:631/ipp/print"
    fi
    while true; do
        state=$(ipptool -t -d "job_id=${job}" "${uri}" "${STATE_TEST}" 2> /dev/null \
            | sed -n 's/.*job-state (enum) = \([a-z-]*\).*/\1/p' | head -n1)
        case "${state}" in
            completed) return 0 ;;
            canceled | aborted) return 1 ;;
            "")
                # Auftrag nicht mehr abrufbar (z. B. schon aus der Liste
                # entfernt): als erledigt werten
                missing=$((missing + 1))
                [[ "${missing}" -ge 3 ]] && return 0
                ;;
            pending | pending-held | processing-stopped)
                missing=0
                if [[ "${waiting}" != "true" ]]; then
                    bashio::log.info "Druckordner: Auftrag ${job} wartet auf den Drucker (eingeschaltet, Papier?)"
                    waiting=true
                fi
                ;;
            *) missing=0 ;;
        esac
        sleep 5
    done
}

# Verschieben und das Datum auf jetzt setzen: Das Aufräumen zählt die Tage ab
# dem Drucken, nicht ab dem ursprünglichen Dateidatum
move_to() {
    mv -f "$1" "$2" && touch "$2"
}

handle() {
    local file="$1" base printer stamp job
    base="${file##*/}"

    [[ -f "${file}" ]] || return 0
    stamp=$(date +%Y-%m-%d_%H-%M-%S)
    case "${base,,}" in
        .*) return 0 ;;
        *.pdf | *.ps | *.jpg | *.jpeg | *.png) ;;
        *)
            bashio::log.warning "Druckordner: ${base} übersprungen (unterstützt: PDF, PostScript, JPEG, PNG)"
            move_to "${file}" "${FAILED_DIR}/${stamp}_${base}"
            return 0
            ;;
    esac

    printer=$(printer_name)
    if [[ -z "${printer}" ]]; then
        bashio::log.warning "Druckordner: Kein Drucker eingerichtet – ${base} bleibt liegen"
        return 0
    fi

    printf '%s\n' "${base}" > "${MARKER}"
    if job=$(submit "${file}" "${printer}"); then
        bashio::log.info "Druckordner: ${base} an ${printer} gesendet (Auftrag ${job})"
        if wait_for_job "${printer}" "${job}"; then
            bashio::log.info "Druckordner: ${base} gedruckt"
            move_to "${file}" "${DONE_DIR}/${stamp}_${base}"
        else
            bashio::log.warning "Druckordner: ${base} wurde abgebrochen oder ist fehlgeschlagen"
            move_to "${file}" "${FAILED_DIR}/${stamp}_${base}"
        fi
    else
        bashio::log.error "Druckordner: ${base} konnte nicht gedruckt werden"
        move_to "${file}" "${FAILED_DIR}/${stamp}_${base}"
    fi
    rm -f "${MARKER}"
}

# Neustart während eines Drucks: Ob die Datei fertig gedruckt wurde, ist
# unklar. Nicht noch einmal drucken (doppelte Seiten), sondern nach "fehler/"
if [[ -s "${MARKER}" ]]; then
    base=$(<"${MARKER}")
    if [[ -f "${FOLDER}/${base}" ]]; then
        bashio::log.warning "Druckordner: Neustart während des Drucks von ${base} – nach fehler/ verschoben, bitte prüfen"
        move_to "${FOLDER}/${base}" "${FAILED_DIR}/$(date +%Y-%m-%d_%H-%M-%S)_${base}"
    fi
fi
rm -f "${MARKER}"

bashio::log.info "Druckordner aktiv: ${FOLDER} (${MEDIA_PPD}, ${COLOR}, Qualität ${QUALITY})"

# Erst vorhandene Dateien, dann neue (fertig geschrieben oder hineinverschoben)
for file in "${FOLDER}"/*; do
    handle "${file}"
done

inotifywait -m -q -e close_write -e moved_to --format '%w%f' "${FOLDER}" \
    | while IFS= read -r file; do
        handle "${file}"
    done
