#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Abbrechen von Druckaufträgen durchsetzen (Modus "printer_app")
#
# Die Legacy Printer Application markiert einen abgebrochenen Auftrag nur als
# "processing-to-stop-point", lässt den Brother-Filter aber zu Ende rechnen –
# die Seite würde trotzdem gedruckt. Solange ein Brother-Filter läuft, fragt
# dieser Dienst den Auftragsstatus ab und bricht den Auftrag ab:
#
#  1. Nur Ghostscript beenden: Der Brother-Filter bekommt dann ein Dateiende,
#     schließt die angefangene Seite sauber ab (Seitenvorschub + Reset) und der
#     Drucker wirft das Blatt aus – wie beim Abbrechen unter Windows.
#  2. Läuft der Filter nach 20 Sekunden immer noch, die ganze Kette beenden.
#
# Ohne laufenden Druck passiert nichts.
# ==============================================================================

readonly FILTER="brlpdwrappermfc260c"
readonly PRINTER_URI="ipp://localhost:631/ipp/print"
readonly TEST_FILE="/usr/share/cups-addon/ipptool/job-state.test"
readonly FORCE_AFTER=20

# Zeitpunkt des ersten Abbruchversuchs je Auftrag
declare -A canceled_at=()

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
        canceled_at=()
        sleep 2
        continue
    fi

    while read -r pid job_id; do
        [[ -n "${pid}" && "${job_id}" =~ ^[0-9]+$ ]] || continue

        if [[ -z "${canceled_at[${job_id}]:-}" ]]; then
            reasons=$(ipptool -t -d "job_id=${job_id}" "${PRINTER_URI}" "${TEST_FILE}" 2>/dev/null || true)
            [[ "${reasons}" == *"processing-to-stop-point"* ]] || continue
            bashio::log.info "Druckauftrag ${job_id} abgebrochen – Seite wird abgeschlossen und ausgeworfen"
            canceled_at[${job_id}]=$(date +%s)
        fi

        tree=$(descendants "${pid}")
        # Schritt 1: Ghostscript (und die Prozesse, die ihn füttern) beenden
        for child in ${tree}; do
            case "$(ps -o comm= -p "${child}" 2>/dev/null)" in
                gs | cat) kill -TERM "${child}" 2>/dev/null || true ;;
            esac
        done

        # Schritt 2: Notbremse
        if (($(date +%s) - canceled_at[${job_id}] >= FORCE_AFTER)); then
            bashio::log.warning "Druckauftrag ${job_id}: Filter reagiert nicht – beende ihn vollständig"
            # shellcheck disable=SC2086
            kill -TERM ${tree} "${pid}" 2>/dev/null || true
        fi
    done <<<"${running}"

    sleep 3
done
