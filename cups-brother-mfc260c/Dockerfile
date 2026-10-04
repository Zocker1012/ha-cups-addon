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

# Eigene Anpassung: maximale Auflösung begrenzbar (AIRSANE_MAX_RESOLUTION)
COPY patches/ /tmp/patches/

RUN git clone --depth 1 --branch "${AIRSANE_VERSION}" \
        https://github.com/SimulPiscator/AirSane /src/airsane \
    && test "$(git -C /src/airsane rev-parse HEAD)" = "${AIRSANE_COMMIT}" \
    && git -C /src/airsane apply /tmp/patches/airsane-max-resolution.patch \
    && cmake -S /src/airsane -B /src/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /src/build -j"$(nproc)" \
    && install -Dm755 /src/build/airsaned /out/usr/sbin/airsaned \
    && install -Dm644 /src/airsane/etc/Gnome-scanner.png /out/etc/airsane/Gnome-scanner.png \
    && install -Dm644 /src/airsane/etc/access.conf /out/etc/airsane/access.conf \
    && install -Dm644 /src/airsane/etc/ignore.conf /out/etc/airsane/ignore.conf

# ==============================================================================
# Brother-Scannertreiber (brscan2) und Scan-Tasten-Tool (brscan-skey)
# Offizielle Pakete von Brother, per Prüfsumme kontrolliert. Liegen passende
# Dateien in drivers/, werden diese verwendet. Fehlt ein Paket, wird ohne die
# jeweilige Funktion weitergebaut – das Add-on meldet das beim Start.
# ==============================================================================
FROM ${BUILD_FROM} AS brother-scan

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates coreutils cpio curl rpm2cpio \
    && rm -rf /var/lib/apt/lists/*

COPY drivers/ /drivers/

WORKDIR /tmp/pkg

# fetch NAME URL HASH-PROGRAMM HASH ZIEL: lokal aus drivers/ oder Download, Hash prüfen
# hadolint ignore=SC2016
RUN fetch() { \
        local name="$1" url="$2" hashprog="$3" hash="$4" target="$5"; \
        if [ -f "/drivers/${name}" ]; then cp "/drivers/${name}" "${target}"; \
        elif ! curl -fsSL --retry 3 -o "${target}" "${url}"; then \
            echo "WARNUNG: ${name} nicht herunterladbar"; return 1; fi; \
        if ! echo "${hash}  ${target}" | "${hashprog}" -c -; then \
            echo "WARNUNG: Prüfsumme von ${name} falsch"; rm -f "${target}"; return 1; fi; \
    }; \
    mkdir -p /out; \
    if fetch brscan2-0.2.5-1.x86_64.rpm \
            https://download.brother.com/welcome/dlf006640/brscan2-0.2.5-1.x86_64.rpm \
            sha256sum ab02c4e2292e9847a0338a225973735ccaec49c3d443f584004c8f91f5d6a8c9 \
            brscan2.rpm; then \
        rpm2cpio /tmp/pkg/brscan2.rpm | cpio -idm --quiet -D /out; \
    fi; \
    if fetch brscan-skey-0.2.4-1.x86_64.rpm \
            https://download.brother.com/welcome/dlf006650/brscan-skey-0.2.4-1.x86_64.rpm \
            sha256sum 2e034b37e282e44a6f94315d932eb8f34693007e4abd10ca10fb4ec468c9bb3d \
            skey.rpm \
        || fetch brscan-skey-0.3.5-0.x86_64.rpm \
            https://download.brother.com/welcome/dlf006650/brscan-skey-0.3.5-0.x86_64.rpm \
            b2sum 22498692f345da364d116b026314a7a9d29916102b571604435918fda80dfc624754bd1bd8e50c2d246cb5649ffc7850a3579aa2063cb5c44948d3f505c521df \
            skey.rpm; then \
        rpm2cpio /tmp/pkg/skey.rpm | cpio -idm --quiet -D /out; \
    fi; \
    find /out -maxdepth 4 | sort

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
        # Druckordner
        inotify-tools \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Brother MFC-260C Treiber aus dem Repo installieren.
# Das Postinst erzeugt PPD und CUPS-Filter. Es versucht außerdem, cupsd per
# init-Skript neu zu starten und eine Queue anzulegen – das wird im Build
# unterbunden (init-Skript kurz weg), die Fehlermeldung von lpadmin ist normal.
COPY drivers/ /tmp/drivers/

RUN mkdir -p /var/spool/lpd \
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
    for cmd in gs pdf2ps file psnup a2ps; do command -v "${cmd}"; done; \
    rc=0; \
    /usr/local/Brother/Printer/mfc260c/lpd/brmfc260cfilter < /dev/null > /dev/null 2>&1 || rc=$?; \
    if [ "${rc}" -ge 126 ]; then \
        echo "Brother i386-Filter nicht ausführbar (rc=${rc})"; exit 1; \
    fi; \
    PPD_DIRS=/usr/share/cups-addon/ppd USER_PPD_DIR=/tmp/ppd \
    FILTER_DIR=/usr/lib/cups/filter BACKEND_DIR=/usr/lib/cups/backend \
        legacy-printer-app drivers | grep -i 'mfc-\?260c'

RUN rm -f /etc/nginx/sites-enabled/default \
    # PAM-Modul für die Anmeldung (siehe rootfs/etc/pam.d)
    && test -f /usr/lib/x86_64-linux-gnu/security/pam_exec.so

# Scanner: AirSane und Brother-Treiber übernehmen und einbinden
COPY --from=airsane /out/ /
COPY --from=brother-scan /out/ /

RUN set -e; \
    if [ -e /usr/lib64/sane/libsane-brother2.so.1 ]; then \
        echo /usr/lib64 > /etc/ld.so.conf.d/brother-scan.conf; \
        ldconfig; \
        sane_dir=/usr/lib/x86_64-linux-gnu/sane; \
        ln -sf /usr/lib64/sane/libsane-brother2.so.1 "${sane_dir}/libsane-brother2.so.1"; \
        ln -sf /usr/lib64/sane/libsane-brother2.so.1 "${sane_dir}/libsane-brother2.so"; \
        grep -q '^0x01d6.*MFC-260C' /usr/local/Brother/sane/models2/ext1.ini; \
        touch /usr/share/cups-addon-scan-driver; \
    fi; \
    # Nur den Brother-Treiber laden: schneller und kein Herumprobieren an anderen USB-Geräten
    echo brother2 > /etc/sane.d/dll.conf; \
    if [ -f /opt/brother/scanner/brscan-skey/brscan-skey.config ] \
        || ls /opt/brother/scanner/brscan-skey/brscan-skey-*.cfg > /dev/null 2>&1; then \
        touch /usr/share/cups-addon-scan-button; \
    fi

COPY rootfs /

EXPOSE 631
