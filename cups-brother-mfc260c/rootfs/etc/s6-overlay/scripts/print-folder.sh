#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Druckordner: Neue Dateien automatisch drucken
# Gedruckte Dateien wandern nach "gedruckt/", fehlerhafte nach "fehler/".
# ==============================================================================

FOLDER=$(bashio::config 'print_folder_path')
readonly FOLDER
readonly DONE_DIR="${FOLDER}/gedruckt"
readonly FAILED_DIR="${FOLDER}/fehler"
MODE=$(bashio::config 'mode')
readonly MODE

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

submit() {
    local file="$1" printer="$2"
    if [[ "${MODE}" == "cups" ]]; then
        lp -d "${printer}" -t "${file##*/}" -- "${file}" > /dev/null
    else
        legacy-printer-app submit -d "${printer}" "${file}" > /dev/null
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

bashio::log.info "Druckordner aktiv: ${FOLDER}"

# Erst vorhandene Dateien, dann neue (fertig geschrieben oder hineinverschoben)
for file in "${FOLDER}"/*; do
    handle "${file}"
done

inotifywait -m -q -e close_write -e moved_to --format '%w%f' "${FOLDER}" \
    | while IFS= read -r file; do
        handle "${file}"
    done
