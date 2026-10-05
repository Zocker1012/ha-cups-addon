#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# shellcheck shell=bash
# ==============================================================================
# Gemeinsame Umgebung für die Legacy Printer Application (Server und CLI)
# ==============================================================================

export STATE_DIR="/data/legacy-printer-app"
export STATE_FILE="${STATE_DIR}/legacy-printer-app.state"
export SPOOL_DIR="/var/spool/legacy-printer-app"
export FILTER_DIR="/usr/lib/cups/filter"
export BACKEND_DIR="/usr/lib/cups/backend"
export USER_PPD_DIR="${STATE_DIR}/ppd"
# Nur die angepasste Brother-PPD anbieten (siehe Dockerfile) plus eigene Uploads
export PPD_DIRS="/usr/share/cups-addon/ppd:${USER_PPD_DIR}"
