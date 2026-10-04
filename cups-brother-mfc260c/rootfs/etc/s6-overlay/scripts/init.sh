#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Add-on initialisieren: Verzeichnisse, Admin-Passwort, Treiber-Debug, Ingress
# ==============================================================================

readonly ADMIN_USER="print"
readonly PASSWORD_FILE="/data/admin_password"
readonly BROTHER_WRAPPER="/usr/lib/cups/filter/brlpdwrappermfc260c"

# Reste eines vorherigen Laufs entfernen (Container-Neustart):
# zwischengespeicherte Optionen, alte Sockets und PID-Dateien
rm -rf /tmp/.bashio
rm -f \
    /run/dbus/pid \
    /run/dbus/system_bus_socket \
    /run/avahi-daemon/pid \
    /run/avahi-daemon/socket \
    /run/cups/cups.sock \
    /run/legacy-printer-app.sock

mkdir -p \
    /run/dbus \
    /run/cups-addon \
    /data/cups \
    /data/legacy-printer-app

bashio::log.info "Modus: $(bashio::config 'mode')"

# ------------------------------------------------------------------------------
# Admin-Passwort (Benutzer "print") – aus der Option oder einmalig generiert
# ------------------------------------------------------------------------------
if bashio::config.has_value 'admin_password'; then
    password=$(bashio::config 'admin_password')
    rm -f "${PASSWORD_FILE}"
else
    if [[ ! -s "${PASSWORD_FILE}" ]]; then
        openssl rand -base64 18 | tr -d '/+=\n' > "${PASSWORD_FILE}"
        chmod 600 "${PASSWORD_FILE}"
    fi
    password=$(<"${PASSWORD_FILE}")
    bashio::log.warning "Option 'admin_password' ist leer – generiertes Passwort für Benutzer '${ADMIN_USER}': ${password}"
fi

echo "${ADMIN_USER}:${password}" | chpasswd
printf '%s' "${password}" > /run/cups-addon/admin_password
chmod 600 /run/cups-addon/admin_password

# ------------------------------------------------------------------------------
# Brother-Treiber: Debug-Log bei log_level "debug" einschalten
# ------------------------------------------------------------------------------
if [[ "$(bashio::config 'log_level')" == "debug" ]]; then
    sed -i 's/^DEBUG=0$/DEBUG=1/' "${BROTHER_WRAPPER}"
else
    sed -i 's/^DEBUG=1$/DEBUG=0/' "${BROTHER_WRAPPER}"
fi

# ------------------------------------------------------------------------------
# nginx-Konfiguration für Ingress erzeugen
# ------------------------------------------------------------------------------
ingress_port=$(bashio::addon.ingress_port)
ingress_entry=$(bashio::addon.ingress_entry)
auth=$(printf '%s:%s' "${ADMIN_USER}" "${password}" | base64 -w0)

bashio::var.json \
    port "^${ingress_port}" \
    entry "${ingress_entry}" \
    auth "${auth}" \
    | tempio \
        -template /etc/nginx/templates/ingress.gtpl \
        -out /etc/nginx/conf.d/ingress.conf
