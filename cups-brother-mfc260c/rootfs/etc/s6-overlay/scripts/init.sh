#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Add-on initialisieren: Verzeichnisse, Anmeldung, Treiber-Debug, Ingress
# ==============================================================================

readonly RUN_DIR="/run/cups-addon"
readonly PASSWORD_FILE="/data/admin_password"
readonly BROTHER_WRAPPER="/usr/lib/cups/filter/brlpdwrappermfc260c"

# Reste eines vorherigen Laufs entfernen (Container-Neustart):
# zwischengespeicherte Optionen, alte Sockets und PID-Dateien
rm -rf /tmp/.bashio "${RUN_DIR}"
rm -f \
    /run/dbus/pid \
    /run/dbus/system_bus_socket \
    /run/avahi-daemon/pid \
    /run/avahi-daemon/socket \
    /run/cups/cups.sock \
    /run/legacy-printer-app.sock

mkdir -p \
    /run/dbus \
    /data/cups \
    /data/legacy-printer-app

# Nur root darf die Anmeldedaten lesen
mkdir -m 700 "${RUN_DIR}"

bashio::log.info "Modus: $(bashio::config 'mode')"

# Lokales Konto (Admin-Gruppe) anlegen – das Passwort prüft PAM, nicht /etc/shadow
add_admin_account() {
    if ! id "${1}" > /dev/null 2>&1; then
        useradd --no-create-home --no-user-group --groups lpadmin \
            --shell /usr/sbin/nologin "${1}"
    fi
}

# ------------------------------------------------------------------------------
# Anmeldung für die Web-Administration (geprüft von cups-addon-auth über PAM)
# ------------------------------------------------------------------------------
auth_mode="homeassistant"
if [[ "$(bashio::config 'auth')" == "manual" ]]; then
    auth_mode="manual"
fi
printf '%s' "${auth_mode}" > "${RUN_DIR}/auth_mode"

if [[ "${auth_mode}" == "homeassistant" ]]; then
    printf '%s' "${SUPERVISOR_TOKEN:-}" > "${RUN_DIR}/supervisor_token"
    printf '%s' "${SUPERVISOR_API:-http://supervisor}" > "${RUN_DIR}/supervisor_api"
    bashio::log.info "Anmeldung: mit einem Home-Assistant-Benutzerkonto"
else
    admin_user="print"
    if bashio::config.has_value 'admin_username'; then
        admin_user=$(bashio::config 'admin_username')
    fi

    if bashio::config.has_value 'admin_password'; then
        password=$(bashio::config 'admin_password')
        rm -f "${PASSWORD_FILE}"
    else
        if [[ ! -s "${PASSWORD_FILE}" ]]; then
            openssl rand -base64 18 | tr -d '/+=\n' > "${PASSWORD_FILE}"
            chmod 600 "${PASSWORD_FILE}"
        fi
        password=$(<"${PASSWORD_FILE}")
        bashio::log.warning "Option 'admin_password' ist leer – generiertes Passwort für Benutzer '${admin_user}': ${password}"
    fi

    printf '%s' "${admin_user}" > "${RUN_DIR}/admin_user"
    printf '%s' "${password}" > "${RUN_DIR}/admin_password"
    if [[ "${admin_user}" =~ ^[a-z_][a-z0-9_.-]{0,31}$ ]]; then
        add_admin_account "${admin_user}"
    fi
    bashio::log.info "Anmeldung: manuell als Benutzer '${admin_user}'"
fi

# Die Printer Application kennt keine Benutzerkonten, nur ein Admin-Passwort
# für die Weboberfläche: das manuelle Passwort bzw. bei Anmeldung über
# Home Assistant ein zufälliges (Verwaltung dann nur über die HA-Seitenleiste)
if [[ "${auth_mode}" == "manual" ]]; then
    printf '%s' "${password}" > "${RUN_DIR}/web_password"
else
    openssl rand -hex 24 | tr -d '\n' > "${RUN_DIR}/web_password"
fi

# Ingress-Proxy meldet sich mit einem zufälligen Token an (Modus "cups");
# im Modus "printer_app" setzt ingress-session.sh das Login-Cookie
ingress_token=$(openssl rand -hex 24)
printf '%s' "${ingress_token}" > "${RUN_DIR}/ingress_token"
add_admin_account ingress
: > "${RUN_DIR}/ingress-cookie.conf"

# ------------------------------------------------------------------------------
# Avahi nur auf echten Netzwerkschnittstellen (nicht auf internen Docker-/
# Home-Assistant-Netzen) – weniger Log, keine Ankündigung in internen Netzen
# ------------------------------------------------------------------------------
interfaces=()
for iface in /sys/class/net/*; do
    iface="${iface##*/}"
    case "${iface}" in
        lo | docker* | hassio | veth* | br-* | virbr* | tun* | tap* | wg* | dummy*) continue ;;
    esac
    [[ -e "/sys/class/net/${iface}/device" || -d "/sys/class/net/${iface}/wireless" ]] || continue
    interfaces+=("${iface}")
done
if [[ "${#interfaces[@]}" -gt 0 ]]; then
    allow=$(IFS=,; echo "${interfaces[*]}")
    sed -i "s/^#\?allow-interfaces=.*/allow-interfaces=${allow}/" /etc/avahi/avahi-daemon.conf
    bashio::log.info "mDNS/AirPrint auf: ${allow}"
fi

# ------------------------------------------------------------------------------
# Brother-Treiber: Debug-Log bei log_level "debug" einschalten
# ------------------------------------------------------------------------------
if [[ "$(bashio::config 'log_level')" == "debug" ]]; then
    sed -i 's/^DEBUG=0$/DEBUG=1/' "${BROTHER_WRAPPER}"
else
    sed -i 's/^DEBUG=1$/DEBUG=0/' "${BROTHER_WRAPPER}"
fi

# ------------------------------------------------------------------------------
# Scanner: Einstellungen für die Scan-Taste, Ordner anlegen
# ------------------------------------------------------------------------------
scanner=false
if bashio::config.true 'scanner'; then
    if [[ -e /usr/share/cups-addon-scan-driver ]]; then
        scanner=true
    else
        bashio::log.warning "Scanner: Brother-Scannertreiber (brscan2) fehlt im Image – Scanner deaktiviert. Siehe Dokumentation."
    fi
fi
printf '%s' "${scanner}" > "${RUN_DIR}/scanner_enabled"

if [[ "${scanner}" == "true" ]] && bashio::config.true 'scan_button'; then
    scan_folder=$(bashio::config 'scan_folder')
    mkdir -p "${scan_folder}"
    {
        printf 'SCAN_FOLDER=%q\n' "${scan_folder}"
        printf 'SCAN_FORMAT=%q\n' "$(bashio::config 'scan_format')"
        printf 'SCAN_RESOLUTION=%q\n' "$(bashio::config 'scan_resolution')"
        printf 'SCAN_MODE=%q\n' "$(bashio::config 'scan_mode')"
        printf 'SCAN_SOURCE=%q\n' "$(bashio::config 'scan_source' 'flatbed')"
    } > "${RUN_DIR}/scan.env"
fi

if bashio::config.true 'print_folder'; then
    mkdir -p "$(bashio::config 'print_folder_path')"
fi

# ------------------------------------------------------------------------------
# nginx-Konfiguration für Ingress erzeugen
# ------------------------------------------------------------------------------
ingress_port=$(bashio::addon.ingress_port)
ingress_entry=$(bashio::addon.ingress_entry)
auth=$(printf 'ingress:%s' "${ingress_token}" | base64 -w0)

bashio::var.json \
    port "^${ingress_port}" \
    entry "${ingress_entry}" \
    auth "${auth}" \
    scanner "^${scanner}" \
    | tempio \
        -template /etc/nginx/templates/ingress.gtpl \
        -out /etc/nginx/conf.d/ingress.conf
chmod 600 /etc/nginx/conf.d/ingress.conf
