#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Abbrechen von Druckaufträgen durchsetzen (Modus "printer_app")
#
# Die Legacy Printer Application markiert einen abgebrochenen Auftrag nur als
# "processing-to-stop-point", lässt den Brother-Filter aber zu Ende rechnen –
# die Seite würde trotzdem gedruckt. Solange ein Brother-Filter läuft, fragt
# dieser Dienst den Auftragsstatus ab und beendet bei einem Abbruch die
# Filterkette des Auftrags. Ohne laufenden Druck passiert nichts.
# ==============================================================================

readonly FILTER="brlpdwrappermfc260c"
readonly PRINTER_URI="ipp://localhost:631/ipp/print"
readonly TEST_FILE="/usr/share/cups-addon/ipptool/job-state.test"

# Alle Nachfahren eines Prozesses (Kinder zuerst ausgeben, dann Eltern)
descendants() {
    local child
    for child in $(pgrep -P "$1"); do
        descendants "${child}"
        echo "${child}"
    done
}

while true; do
    # Laufende Brother-Filter: "<pid> <job-id>"
    running=$(pgrep -af "/usr/lib/cups/filter/${FILTER} " \
        | awk -v f="${FILTER}" '{ for (i = 2; i < NF; i++) if ($i ~ f "$") { print $1, $(i + 1); break } }' || true)

    if [[ -z "${running}" ]]; then
        sleep 2
        continue
    fi

    while read -r pid job_id; do
        [[ -n "${pid}" && "${job_id}" =~ ^[0-9]+$ ]] || continue
        reasons=$(ipptool -t -d "job_id=${job_id}" "${PRINTER_URI}" "${TEST_FILE}" 2>/dev/null || true)
        if [[ "${reasons}" == *"processing-to-stop-point"* ]]; then
            bashio::log.info "Druckauftrag ${job_id} abgebrochen – beende Brother-Filter"
            # shellcheck disable=SC2046
            kill -TERM $(descendants "${pid}") "${pid}" 2>/dev/null || true
        fi
    done <<<"${running}"

    sleep 3
done
