#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# ==============================================================================
# MQTT für Home Assistant (zum Einbinden mit "source")
#
# Das Add-on meldet sich per MQTT-Discovery als Gerät "Brother MFC-260C" mit
# Entitäten an. Zugangsdaten zum Broker schreibt init.sh nach MQTT_ENV –
# fehlt die Datei (MQTT aus oder kein Broker), tun alle Funktionen nichts.
# ==============================================================================

readonly MQTT_ENV="/run/cups-addon/mqtt.env"
readonly MQTT_BASE="cups-addon/mfc260c"
readonly MQTT_DISCOVERY="homeassistant"
readonly MQTT_NODE="cups_mfc260c"

mqtt_enabled() {
    [[ -r "${MQTT_ENV}" ]]
}

# mqtt_pub TOPIC PAYLOAD – gespeichert (retained); leere PAYLOAD löscht
mqtt_pub() {
    local args
    mqtt_enabled || return 0
    # shellcheck source=/dev/null
    source "${MQTT_ENV}"
    args=(-h "${MQTT_HOST}" -p "${MQTT_PORT}" -q 1 -r -t "$1")
    if [[ -n "${MQTT_USER:-}" ]]; then
        args+=(-u "${MQTT_USER}" -P "${MQTT_PASSWORD:-}")
    fi
    if [[ -n "$2" ]]; then
        args+=(-m "$2")
    else
        args+=(-n)
    fi
    timeout 10 mosquitto_pub "${args[@]}" > /dev/null 2>&1 || true
}

# Entitäten: Komponente, Kennung, JSON mit den eigenen Feldern
mqtt_entities() {
    cat << EOF
binary_sensor power {"name":"Eingeschaltet","device_class":"power","state_topic":"${MQTT_BASE}/state","value_template":"{{ value_json.power }}","default_entity_id":"binary_sensor.mfc260c_eingeschaltet"}
sensor jobs {"name":"Druckaufträge","icon":"mdi:file-document-multiple-outline","state_class":"measurement","state_topic":"${MQTT_BASE}/state","value_template":"{{ value_json.jobs }}","default_entity_id":"sensor.mfc260c_druckauftraege"}
sensor status {"name":"Status","icon":"mdi:printer","device_class":"enum","options":["Bereit","Druckt","Wartet auf Drucker","Aus"],"state_topic":"${MQTT_BASE}/state","value_template":"{{ value_json.status }}","default_entity_id":"sensor.mfc260c_status"}
sensor last_scan {"name":"Letzter Scan","icon":"mdi:scanner","state_topic":"${MQTT_BASE}/scan","value_template":"{{ value_json.file }}","json_attributes_topic":"${MQTT_BASE}/scan","default_entity_id":"sensor.mfc260c_letzter_scan"}
sensor mode {"name":"Druckmodus","icon":"mdi:cog-outline","entity_category":"diagnostic","state_topic":"${MQTT_BASE}/state","value_template":"{{ value_json.mode }}","default_entity_id":"sensor.mfc260c_druckmodus"}
EOF
}

# Entitäten anmelden. $1 = Add-on-Version, $2 = Add-on-Kennung (für den Link)
mqtt_discovery_publish() {
    local version="$1" slug="$2" component id fields device
    device=$(jq -cn --arg v "${version}" --arg s "${slug}" '{
        identifiers: ["cups_mfc260c"], name: "Brother MFC-260C",
        manufacturer: "Brother", model: "MFC-260C", sw_version: $v,
        configuration_url: ("homeassistant://hassio/ingress/" + $s)}')
    while read -r component id fields; do
        mqtt_pub "${MQTT_DISCOVERY}/${component}/${MQTT_NODE}/${id}/config" "$(jq -cn \
            --argjson f "${fields}" --argjson d "${device}" \
            --arg u "${MQTT_NODE}_${id}" --arg a "${MQTT_BASE}/availability" \
            '$f + {unique_id: $u, availability_topic: $a, device: $d}')"
    done < <(mqtt_entities)
}

# Entitäten wieder entfernen (MQTT in den Einstellungen ausgeschaltet)
mqtt_discovery_remove() {
    local component id
    while read -r component id _; do
        mqtt_pub "${MQTT_DISCOVERY}/${component}/${MQTT_NODE}/${id}/config" ""
    done < <(mqtt_entities)
    mqtt_pub "${MQTT_BASE}/state" ""
    mqtt_pub "${MQTT_BASE}/scan" ""
    mqtt_pub "${MQTT_BASE}/availability" ""
}
