# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# Basis-Image (früher in build.yaml, das der Supervisor nicht mehr verwenden möchte)
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-ubuntu:26.04

# ==============================================================================
# AirSane: stellt den Scanner treiberlos per AirScan/eSCL bereit
# ==============================================================================
FROM ${BUILD_FROM} AS airsane

ARG AIRSANE_VERSION=v0.4.9
ARG AIRSANE_COMMIT=291513fe0fc8327ebc086447caeb9f0672865faf

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        git \
        libavahi-client-dev \
        libjpeg-dev \
        libpng-dev \
        libsane-dev \
        libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*

# Eigene Anpassungen (patches/): maximale Auflösung begrenzbar
# (AIRSANE_MAX_RESOLUTION), Scanbereich ohne Angabe richtig skalieren
COPY patches/ /tmp/patches/

RUN git clone --depth 1 --branch "${AIRSANE_VERSION}" \
        https://github.com/SimulPiscator/AirSane /src/airsane \
    && test "$(git -C /src/airsane rev-parse HEAD)" = "${AIRSANE_COMMIT}" \
    && for patch in /tmp/patches/airsane-*.patch; do \
        git -C /src/airsane apply "${patch}" || exit 1; \
    done \
    && cmake -S /src/airsane -B /src/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /src/build -j"$(nproc)" \
    && install -Dm755 /src/build/airsaned /out/usr/sbin/airsaned \
    && install -Dm644 /src/airsane/etc/Gnome-scanner.png /out/etc/airsane/Gnome-scanner.png \
    && install -Dm644 /src/airsane/etc/access.conf /out/etc/airsane/access.conf \
    && install -Dm644 /src/airsane/etc/ignore.conf /out/etc/airsane/ignore.conf

# ==============================================================================
# Brother-Scannertreiber (brscan2) und Scan-Key-Tool (brscan-skey) aus
# drivers/: offizielle Pakete von Brother, unverändert und per Prüfsumme
# kontrolliert. Sie werden nur ausgepackt – Brothers Installationsskripte
# laufen nicht, die Einrichtung übernimmt das Dockerfile.
# ==============================================================================
FROM ${BUILD_FROM} AS brother-scan

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends cpio rpm2cpio \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/pkg

COPY drivers/brscan2-0.2.5-1.x86_64.rpm drivers/brscan-skey-0.3.5-0.x86_64.rpm ./

RUN printf '%s  %s\n' \
        ab02c4e2292e9847a0338a225973735ccaec49c3d443f584004c8f91f5d6a8c9 brscan2-0.2.5-1.x86_64.rpm \
        01dc859f1978e645147ced5ec4b5448cc3e26b1c6d2f1104834f5891c0e17469 brscan-skey-0.3.5-0.x86_64.rpm \
        | sha256sum -c - \
    && mkdir -p /out \
    && for rpm in ./*.rpm; do rpm2cpio "${rpm}" | cpio -idm --quiet -D /out; done

# ==============================================================================
# Add-on
# ==============================================================================
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Pakete installieren
# - legacy-printer-app: CUPS-3-Weg (PAPPL Printer Application für klassische PPD-Treiber)
# - cups: klassischer Druckserver (Modus "cups") und USB-Backend für beide Modi
# - cups-browsed wird bewusst NICHT installiert (CVE-2024-47176)
# hadolint ignore=DL3008
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        avahi-daemon \
        cups \
        cups-filters \
        dbus \
        ghostscript \
        legacy-printer-app \
        libnss-mdns \
        nginx \
        openssl \
        # Vom Brother-Filter genutzt – nicht entfernen!
        a2ps \
        file \
        psutils \
        # Die Brother-Binaries (i386) brauchen nur libc.so.6
        libc6:i386 \
        # Scanner: SANE, AirSane-Laufzeit, Brother-Scannertreiber (libusb 0.1)
        libavahi-client3 \
        libjpeg8 \
        libpng16-16t64 \
        libsane1 \
        libusb-0.1-4 \
        libusb-1.0-0 \
        sane-utils \
        # Scan-Menü: Texterkennung (tesseract), PDF verlustfrei aus Seiten-
        # bildern (img2pdf), Textebene/Drehen/Zusammenfügen (qpdf),
        # JPEG verlustfrei optimieren (jpegtran)
        img2pdf \
        libjpeg-turbo-progs \
        qpdf \
        tesseract-ocr \
        tesseract-ocr-deu \
        tesseract-ocr-eng \
        # Druckordner
        inotify-tools \
        # MQTT-Entitäten in Home Assistant
        mosquitto-clients \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Brother MFC-260C Druckertreiber aus drivers/ installieren (Prüfsumme wie beim
# Scanner). Hier wird wirklich installiert: Das Postinst erzeugt PPD und
# CUPS-Filter. Es versucht außerdem, cupsd per init-Skript neu zu starten und
# eine Queue anzulegen – das wird im Build unterbunden (init-Skript kurz weg),
# die Fehlermeldung von lpadmin ist normal.
COPY drivers/mfc260clpr-1.0.1-1.i386.deb drivers/mfc260ccupswrapper-1.0.1-1.i386.deb /tmp/drivers/

RUN printf '%s  %s\n' \
        95b919958db63e38ee8e47e8c8d7ace56d2608c21571e3f8947095bf28385296 /tmp/drivers/mfc260clpr-1.0.1-1.i386.deb \
        5bd516315aebb1e876a165399215dfcecb863606d1d7f068375ef76a6f51822f /tmp/drivers/mfc260ccupswrapper-1.0.1-1.i386.deb \
        | sha256sum -c - \
    && mkdir -p /var/spool/lpd \
    && if [ -e /etc/init.d/cups ]; then mv /etc/init.d/cups /tmp/cups.init; fi \
    && dpkg -i \
        /tmp/drivers/mfc260clpr-1.0.1-1.i386.deb \
        /tmp/drivers/mfc260ccupswrapper-1.0.1-1.i386.deb \
    && if [ -e /tmp/cups.init ]; then mv /tmp/cups.init /etc/init.d/cups; fi \
    && chmod 1777 /var/spool/lpd /var/spool/lpd/mfc260c \
    && rm -rf /tmp/drivers /etc/cups/printers.conf* /etc/cups/ppd/* /run/cups/* /var/log/cups/* \
    # Doppelte PPD vermeiden (der Brother-Installer kopiert sie zusätzlich nach /usr/share/ppd)
    && rm -f /usr/share/ppd/brmfc260c.ppd \
    # PPD-Kopie für die Legacy Printer Application:
    # - Die Brother-PPD benennt Auflösungen nur "Draft/Normal/…", PAPPL braucht
    #   eine DPI-Angabe (sonst "Invalid driver raster resolution 0x0dpi").
    # - Standardformat A4 statt Letter.
    # - Vorschalt-Filter, der das Papierformat jedes Auftrags an den
    #   Brother-Filter weitergibt (siehe rootfs/usr/lib/cups/filter).
    && mkdir -p /usr/share/cups-addon/ppd \
    && sed -E \
        -e '1a *% Angepasst 2026 vom Home-Assistant-Add-on cups-brother-mfc260c (GPL-2.0, siehe dessen Dockerfile): A4, 600dpi, Vorschalt-Filter' \
        -e 's/^\*DefaultResolution: Normal$/*DefaultResolution: 600dpi/' \
        -e 's/^\*Default(PageSize|PageRegion|ImageableArea|PaperDimension): Letter$/*Default\1: A4/' \
        -e 's/^(\*cupsFilter: ".* )brlpdwrappermfc260c"$/\1cups-addon-brmfc260c"/' \
        /usr/share/cups/model/brmfc260c.ppd > /usr/share/cups-addon/ppd/brmfc260c.ppd \
    && grep -q '^\*DefaultResolution: 600dpi$' /usr/share/cups-addon/ppd/brmfc260c.ppd \
    && grep -q '^\*DefaultPageSize: A4$' /usr/share/cups-addon/ppd/brmfc260c.ppd \
    && grep -q '^\*cupsFilter: .* cups-addon-brmfc260c"$' /usr/share/cups-addon/ppd/brmfc260c.ppd

# Build-Checks: bricht ab, wenn der Treiber auf dieser Basis nicht sauber installiert ist
RUN set -e; \
    test -s /usr/share/cups/model/brmfc260c.ppd; \
    test -x /usr/lib/cups/filter/brlpdwrappermfc260c; \
    test -x /usr/lib/cups/backend/usb; \
    for cmd in gs pdf2ps file psnup a2ps tesseract jpegtran img2pdf qpdf mosquitto_pub; do command -v "${cmd}"; done; \
    tesseract --list-langs 2>&1 | grep -qx deu; \
    tesseract --list-langs 2>&1 | grep -qx osd; \
    rc=0; \
    /usr/local/Brother/Printer/mfc260c/lpd/brmfc260cfilter < /dev/null > /dev/null 2>&1 || rc=$?; \
    if [ "${rc}" -ge 126 ]; then \
        echo "Brother i386-Filter nicht ausführbar (rc=${rc})"; exit 1; \
    fi; \
    PPD_DIRS=/usr/share/cups-addon/ppd USER_PPD_DIR=/tmp/ppd \
    FILTER_DIR=/usr/lib/cups/filter BACKEND_DIR=/usr/lib/cups/backend \
        legacy-printer-app drivers | grep -i 'mfc-\?260c'

RUN rm -f /etc/nginx/sites-enabled/default \
    # Braille-Backend aus cups-filters: unnötig und meldet bei jeder
    # Gerätesuche "cups-brf must be called as root"
    && rm -f /usr/lib/cups/backend/cups-brf \
    # PAM-Modul für die Anmeldung (siehe rootfs/etc/pam.d)
    && test -f /usr/lib/x86_64-linux-gnu/security/pam_exec.so

# Scanner: AirSane und Brother-Treiber übernehmen und einbinden
COPY --from=airsane /out/ /
COPY --from=brother-scan /out/ /

# Brother-Bibliotheken liegen in /usr/lib64 (Red-Hat-Pfad), SANE sucht in
# /usr/lib/x86_64-linux-gnu/sane. Danach prüfen: MFC-260C bekannt, alle
# Bibliotheken auflösbar, Scan-Key-Tool vorhanden.
RUN set -e; \
    echo /usr/lib64 > /etc/ld.so.conf.d/brother-scan.conf; \
    ldconfig; \
    sane_dir=/usr/lib/x86_64-linux-gnu/sane; \
    ln -sf /usr/lib64/sane/libsane-brother2.so.1 "${sane_dir}/libsane-brother2.so.1"; \
    ln -sf /usr/lib64/sane/libsane-brother2.so.1 "${sane_dir}/libsane-brother2.so"; \
    # Nur den Brother-Treiber laden: schneller und kein Herumprobieren an anderen USB-Geräten
    echo brother2 > /etc/sane.d/dll.conf; \
    grep -q '^0x01d6.*MFC-260C' /usr/local/Brother/sane/models2/ext1.ini; \
    test -f /opt/brother/scanner/brscan-skey/brscan-skey.config; \
    for bin in "${sane_dir}/libsane-brother2.so.1" /opt/brother/scanner/brscan-skey/brscan-skey-exe; do \
        if ldd "${bin}" | grep 'not found'; then echo "${bin}: Bibliothek fehlt"; exit 1; fi; \
    done

COPY rootfs /

# Lizenzen der Brother-Treiber gehören zu jedem Image dazu
COPY drivers/LICENSE-Brother.txt drivers/LICENSE-GPL-2.0.txt /usr/share/doc/brother-drivers/

EXPOSE 631
