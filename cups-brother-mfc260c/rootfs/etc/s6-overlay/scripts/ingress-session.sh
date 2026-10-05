#!/command/with-contenv bashio
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Ingress-Login für die Printer Application (Modus "printer_app")
#
# Die Weboberfläche von PAPPL fragt nach dem Admin-Passwort und merkt sich die
# Anmeldung in einem Cookie (gültig, bis PAPPL nach 24 Stunden den
# Sitzungsschlüssel erneuert). Dieses Skript meldet sich lokal an und lässt
# nginx das Cookie bei Anfragen aus der HA-Seitenleiste mitschicken – Home
# Assistant hat den Benutzer dort bereits angemeldet.
# ==============================================================================

readonly BASE_URL="http://127.0.0.1:631"
readonly LOGIN_PAGE="/security"
readonly COOKIE_CONF="/run/cups-addon/ingress-cookie.conf"
readonly PASSWORD_FILE="/run/cups-addon/web_password"
# Selten prüfen, damit das Log nicht vollläuft (Schlüssel wechselt nur täglich)
readonly INTERVAL=300

# Ist die Seite mit diesem Cookie noch die Login-Seite?
is_logged_in() {
    ! curl -s --max-time 10 -H 'Host: localhost:631' -H "Cookie: auth=${1}" \
        "${BASE_URL}${LOGIN_PAGE}" | grep -q 'name="password"'
}

# Anmelden und das neue Cookie ausgeben
login() {
    local csrf

    csrf=$(curl -s --max-time 10 -H 'Host: localhost:631' "${BASE_URL}${LOGIN_PAGE}" \
        | grep -oE 'name="session" value="[0-9a-f]+"' \
        | head -n1 \
        | sed -E 's/.*value="([0-9a-f]+)"/\1/') || return 1
    [[ -n "${csrf}" ]] || return 1

    curl -s --max-time 10 -o /dev/null -D - -H 'Host: localhost:631' \
        --data-urlencode "session=${csrf}" \
        --data-urlencode "password@${PASSWORD_FILE}" \
        "${BASE_URL}${LOGIN_PAGE}" \
        | grep -ioE '^set-cookie: auth=[0-9a-f]+' \
        | head -n1 \
        | cut -d= -f2
}

cookie=""
while true; do
    if [[ -z "${cookie}" ]] || ! is_logged_in "${cookie}"; then
        new_cookie=$(login) || new_cookie=""
        if [[ -n "${new_cookie}" ]]; then
            cookie="${new_cookie}"
            printf 'proxy_set_header Cookie "auth=%s";\n' "${cookie}" > "${COOKIE_CONF}"
            nginx -s reload > /dev/null 2>&1 || true
            bashio::log.debug "Ingress-Login für die Printer Application erneuert"
        else
            sleep 5
            continue
        fi
    fi
    sleep "${INTERVAL}"
done
