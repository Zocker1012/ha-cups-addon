#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Druckordner: Neue Dateien automatisch drucken
# Gedruckte Dateien wandern nach "gedruckt/", fehlerhafte nach "fehler/".
# ==============================================================================

FOLDER=$(bashio::config 'folder_printing.path')
readonly FOLDER
readonly DONE_DIR="${FOLDER}/gedruckt"
readonly FAILED_DIR="${FOLDER}/fehler"
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
        name=$(lpstat -d 2>/dev/null | sed -n 's/^.*: //p')
        [[ -n "${name}" ]] || name=$(lpstat -p 2>/dev/null | awk 'NR==1 {print $2}')
    else
        # shellcheck source=printer-app-env.sh
        source /etc/s6-overlay/scripts/printer-app-env.sh
        name=$(legacy-printer-app printers 2>/dev/null | head -n1)
    fi
    echo "${name}"
}

# Druckoptionen: Papierformat, Farbe und Qualität aus den Einstellungen
# (Modus "cups": PPD-Optionen des Brother-Treibers, sonst IPP-Attribute)
submit() {
    local file="$1" printer="$2" opts=()
    if [[ "${MODE}" == "cups" ]]; then
        opts+=(-o "media=${MEDIA_PPD}")
        [[ "${COLOR}" == "gray" ]] && opts+=(-o BRMonoColor=BrMono)
        case "${QUALITY}" in
            draft) opts+=(-o Resolution=Draft) ;;
            fine) opts+=(-o Resolution=Fine) ;;
        esac
        lp -d "${printer}" -t "${file##*/}" "${opts[@]}" -- "${file}" > /dev/null
    else
        opts+=(-o "media=${MEDIA_IPP}")
        [[ "${COLOR}" == "gray" ]] && opts+=(-o print-color-mode=monochrome)
        case "${QUALITY}" in
            draft) opts+=(-o quality=fast) ;;
            fine) opts+=(-o quality=fine) ;;
        esac
        legacy-printer-app submit -d "${printer}" "${opts[@]}" "${file}" > /dev/null
    fi
}

handle() {
    local file="$1" base printer stamp
    base="${file##*/}"

    [[ -f "${file}" ]] || return 0
    case "${base,,}" in
        .*) return 0 ;;
        *.pdf | *.ps | *.jpg | *.jpeg | *.png) ;;
        *)
            bashio::log.warning "Druckordner: ${base} übersprungen (unterstützt: PDF, PostScript, JPEG, PNG)"
            mv -f "${file}" "${FAILED_DIR}/" || true
            return 0
            ;;
    esac

    printer=$(printer_name)
    stamp=$(date +%Y-%m-%d_%H-%M-%S)
    if [[ -z "${printer}" ]]; then
        bashio::log.warning "Druckordner: Kein Drucker eingerichtet – ${base} bleibt liegen"
        return 0
    fi

    if submit "${file}" "${printer}"; then
        bashio::log.info "Druckordner: ${base} an ${printer} gesendet"
        mv -f "${file}" "${DONE_DIR}/${stamp}_${base}"
    else
        bashio::log.error "Druckordner: ${base} konnte nicht gedruckt werden"
        mv -f "${file}" "${FAILED_DIR}/${stamp}_${base}"
    fi
}

bashio::log.info "Druckordner aktiv: ${FOLDER} (${MEDIA_PPD}, ${COLOR}, Qualität ${QUALITY})"

# Erst vorhandene Dateien, dann neue (fertig geschrieben oder hineinverschoben)
for file in "${FOLDER}"/*; do
    handle "${file}"
done

inotifywait -m -q -e close_write -e moved_to --format '%w%f' "${FOLDER}" \
    | while IFS= read -r file; do
        handle "${file}"
    done
