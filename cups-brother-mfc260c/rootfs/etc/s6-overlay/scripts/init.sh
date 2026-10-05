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

# ------------------------------------------------------------------------------
# Ältere Einstellungen einmalig ins aktuelle Format übernehmen:
#   2.4.x (flach) -> Gruppen (2.5.0), Scan-Menü in einer Gruppe -> je
#   Menüpunkt eine Gruppe (2.11.0). Werte bleiben erhalten, auch "aus" (false).
# ------------------------------------------------------------------------------
migrate_options() {
    local old new
    old=$(bashio::addon.options) || return 0
    new="${old}"

    if jq -e 'has("mode") or has("auth") or has("scanner") or has("scan_button")
        or has("print_folder") or has("auto_setup")' <<< "${new}" > /dev/null; then
        new=$(jq -c '
            def pick(k; d): if has(k) and .[k] != null then .[k] else d end;
            {
              printer: {mode: pick("mode"; "printer_app"),
                        auto_setup: pick("auto_setup"; true)},
              login: ({method: pick("auth"; "homeassistant")}
                      + (if (.admin_username // "") != "" then {username: .admin_username} else {} end)
                      + (if (.admin_password // "") != "" then {password: .admin_password} else {} end)),
              scanning: {enabled: pick("scanner"; true),
                         max_resolution: (pick("scan_max_resolution"; "600")
                                          | if . == "1200" then . else "600" end)},
              scan_menu: {enabled: pick("scan_button"; true),
                           folder: pick("scan_folder"; "/share/scans"),
                           format: pick("scan_format"; "pdf"),
                           resolution: pick("scan_resolution"; "300"),
                           color: pick("scan_mode"; "color")},
              folder_printing: {enabled: pick("print_folder"; false),
                                path: pick("print_folder_path"; "/share/print")},
              log_level: pick("log_level"; "info")
            }' <<< "${new}") || return 0
    fi

    if jq -e '(.scan_menu // {}) | has("format") or has("image_format")
        or has("ocr_format") or has("email_format") or has("ocr_text")' <<< "${new}" > /dev/null; then
        new=$(jq -c '
            def pick(o; k; d): if (o | has(k)) and o[k] != null then o[k] else d end;
            .scan_menu as $m
            | del(.scan_file, .scan_image, .scan_text, .scan_email)
            + {
                scan_menu: {enabled: pick($m; "enabled"; true),
                            folder: pick($m; "folder"; "/share/scans")},
                scan_file: {format: pick($m; "format"; "pdf"),
                            resolution: pick($m; "resolution"; "300"),
                            color: pick($m; "color"; "color")},
                scan_image: {format: pick($m; "image_format"; "jpeg"),
                             resolution: pick($m; "image_resolution"; "300"),
                             color: pick($m; "image_color"; "color")},
                scan_text: {format: pick($m; "ocr_format"; "pdf"),
                            resolution: pick($m; "ocr_resolution"; "300"),
                            color: pick($m; "ocr_color"; "gray"),
                            ocr: pick($m; "ocr_text"; true),
                            language: pick($m; "ocr_language"; "deu_eng"),
                            rotate: pick($m; "ocr_rotate"; true)},
                scan_email: {format: pick($m; "email_format"; "pdf"),
                             resolution: pick($m; "email_resolution"; "150"),
                             color: pick($m; "email_color"; "color")}
              }' <<< "${new}") || return 0
    fi

    [[ "${new}" != "${old}" ]] || return 0
    if bashio::api.supervisor POST /addons/self/options \
        "$(jq -c -n --argjson o "${new}" '{options: $o}')" > /dev/null; then
        bashio::cache.flush_all
        bashio::log.info "Einstellungen ins neue Format übernommen"
    else
        bashio::log.warning "Alte Einstellungen konnten nicht übernommen werden – bitte in der Konfiguration neu setzen"
    fi
}
migrate_options

bashio::log.info "Modus: $(bashio::config 'printer.mode')"

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
if [[ "$(bashio::config 'login.method')" == "manual" ]]; then
    auth_mode="manual"
fi
printf '%s' "${auth_mode}" > "${RUN_DIR}/auth_mode"

if [[ "${auth_mode}" == "homeassistant" ]]; then
    printf '%s' "${SUPERVISOR_TOKEN:-}" > "${RUN_DIR}/supervisor_token"
    printf '%s' "${SUPERVISOR_API:-http://supervisor}" > "${RUN_DIR}/supervisor_api"
    bashio::log.info "Anmeldung: mit einem Home-Assistant-Benutzerkonto"
else
    admin_user="print"
    if bashio::config.has_value 'login.username'; then
        admin_user=$(bashio::config 'login.username')
    fi

    if bashio::config.has_value 'login.password'; then
        password=$(bashio::config 'login.password')
        rm -f "${PASSWORD_FILE}"
    else
        if [[ ! -s "${PASSWORD_FILE}" ]]; then
            openssl rand -base64 18 | tr -d '/+=\n' > "${PASSWORD_FILE}"
            chmod 600 "${PASSWORD_FILE}"
        fi
        password=$(<"${PASSWORD_FILE}")
        bashio::log.warning "Anmeldung → Passwort ist leer – generiertes Passwort für Benutzer '${admin_user}': ${password}"
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
# Scanner: Einstellungen für das Scan-Menü am Gerät, Ordner anlegen
# ------------------------------------------------------------------------------
scanner=false
if bashio::config.true 'scanning.enabled'; then
    if [[ -e /usr/share/cups-addon-scan-driver ]]; then
        scanner=true
    else
        bashio::log.warning "Scanner: Brother-Scannertreiber (brscan2) fehlt im Image – Scanner deaktiviert. Siehe Dokumentation."
    fi
fi
printf '%s' "${scanner}" > "${RUN_DIR}/scanner_enabled"

if [[ "${scanner}" == "true" ]] && bashio::config.true 'scan_menu.enabled'; then
    scan_folder=$(bashio::config 'scan_menu.folder')
    mkdir -p "${scan_folder}"
    {
        printf 'SCAN_FOLDER=%q\n' "${scan_folder}"
        # Menüpunkt (Name im Skript, Gruppe), Standard für Format, Auflösung, Farbe
        for entry in "FILE:scan_file:pdf:300:color" "IMAGE:scan_image:jpeg:300:color" \
            "OCR:scan_text:pdf:300:gray" "EMAIL:scan_email:pdf:150:color"; do
            IFS=: read -r name group def_format def_res def_color <<< "${entry}"
            printf 'SCAN_%s_FORMAT=%q\n' "${name}" "$(bashio::config "${group}.format" "${def_format}")"
            printf 'SCAN_%s_RESOLUTION=%q\n' "${name}" "$(bashio::config "${group}.resolution" "${def_res}")"
            printf 'SCAN_%s_MODE=%q\n' "${name}" "$(bashio::config "${group}.color" "${def_color}")"
        done
        printf 'SCAN_OCR_TEXT=%q\n' "$(bashio::config 'scan_text.ocr' 'true')"
        printf 'SCAN_OCR_LANG=%q\n' "$(bashio::config 'scan_text.language' 'deu_eng')"
        printf 'SCAN_OCR_ROTATE=%q\n' "$(bashio::config 'scan_text.rotate' 'true')"
    } > "${RUN_DIR}/scan.env"
fi

if bashio::config.true 'folder_printing.enabled'; then
    mkdir -p "$(bashio::config 'folder_printing.path')"
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
