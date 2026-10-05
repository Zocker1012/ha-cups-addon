#!/command/with-contenv bashio
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Aufräumen in zwei Stufen, einmal täglich:
#   1. Dateien, die älter als die eingestellten Tage sind, wandern in den
#      Ordner "Papierkorb" (Unterordner bleiben erhalten).
#   2. Dateien, die länger als die eingestellten Tage im Papierkorb liegen,
#      werden gelöscht.
# Betroffen sind nur der Scan-Ordner und im Druckordner "gedruckt/" und
# "fehler/" – nie Dateien, die noch gedruckt werden sollen. 0 Tage = nie.
# ==============================================================================

readonly TRASH="Papierkorb"

SCAN_FOLDER=$(bashio::config 'scan_menu.folder')
PRINT_FOLDER=$(bashio::config 'folder_printing.path')
SCANS_DAYS=$(bashio::config 'cleanup.scans_days' '30')
PRINTED_DAYS=$(bashio::config 'cleanup.printed_days' '30')
FAILED_DAYS=$(bashio::config 'cleanup.failed_days' '30')
TRASH_DAYS=$(bashio::config 'cleanup.trash_days' '30')
readonly SCAN_FOLDER PRINT_FOLDER SCANS_DAYS PRINTED_DAYS FAILED_DAYS TRASH_DAYS

# Dateien in <dir> älter als <tage> nach <basis>/Papierkorb verschieben
# (relativer Pfad bleibt, Zeitstempel = Zeitpunkt des Verschiebens)
to_trash() {
    local dir="$1" base="$2" days="$3" file rel dest moved=0
    [[ "${days}" -gt 0 && -d "${dir}" ]] || return 0
    while IFS= read -r -d '' file; do
        rel="${file#"${base}"/}"
        dest="${base}/${TRASH}/${rel}"
        mkdir -p "${dest%/*}"
        if mv -f "${file}" "${dest}"; then
            touch "${dest}"
            moved=$((moved + 1))
        fi
    done < <(find "${dir}" -path "${base}/${TRASH}" -prune -o \
        -type f ! -name '.*' -mmin +$((days * 1440)) -print0)
    if [[ "${moved}" -gt 0 ]]; then
        bashio::log.info "Aufräumen: ${moved} Datei(en) aus ${dir} in den Papierkorb verschoben"
    fi
}

# Papierkorb unter <basis> leeren: Dateien älter als TRASH_DAYS löschen
empty_trash() {
    local trash="$1/${TRASH}" deleted
    [[ "${TRASH_DAYS}" -gt 0 && -d "${trash}" ]] || return 0
    deleted=$(find "${trash}" -type f -mmin +$((TRASH_DAYS * 1440)) -print -delete | wc -l)
    find "${trash}" -mindepth 1 -type d -empty -delete
    if [[ "${deleted}" -gt 0 ]]; then
        bashio::log.info "Aufräumen: ${deleted} Datei(en) endgültig aus ${trash} gelöscht"
    fi
}

run_once() {
    if [[ -n "${SCAN_FOLDER}" && -d "${SCAN_FOLDER}" ]]; then
        to_trash "${SCAN_FOLDER}" "${SCAN_FOLDER}" "${SCANS_DAYS}"
        empty_trash "${SCAN_FOLDER}"
    fi
    if [[ -n "${PRINT_FOLDER}" && -d "${PRINT_FOLDER}" ]]; then
        to_trash "${PRINT_FOLDER}/gedruckt" "${PRINT_FOLDER}" "${PRINTED_DAYS}"
        to_trash "${PRINT_FOLDER}/fehler" "${PRINT_FOLDER}" "${FAILED_DAYS}"
        empty_trash "${PRINT_FOLDER}"
    fi
}

# "30 Tagen" bzw. "nie" für das Log
days_text() {
    if [[ "$1" -gt 0 ]]; then echo "nach $1 Tagen"; else echo "nie"; fi
}

bashio::log.info "Aufräumen aktiv – in den Papierkorb: Scans $(days_text "${SCANS_DAYS}"), gedruckt $(days_text "${PRINTED_DAYS}"), fehler $(days_text "${FAILED_DAYS}"); Papierkorb leeren: $(days_text "${TRASH_DAYS}")"

# Erster Durchlauf kurz nach dem Start, danach einmal täglich
sleep 300
while true; do
    run_once
    sleep 86400
done
