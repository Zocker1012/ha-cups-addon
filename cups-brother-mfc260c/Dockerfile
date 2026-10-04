ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG BUILD_ARCH=amd64
ARG BUILD_VERSION

LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"

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
    # PPD-Kopie für die Legacy Printer Application: Die Brother-PPD benennt
    # Auflösungen nur "Draft/Normal/…", PAPPL braucht aber eine DPI-Angabe
    # (sonst "Invalid driver raster resolution 0x0dpi"). 600 dpi = "Normal".
    && mkdir -p /usr/share/cups-addon/ppd \
    && sed 's/^\*DefaultResolution: Normal$/*DefaultResolution: 600dpi/' \
        /usr/share/cups/model/brmfc260c.ppd > /usr/share/cups-addon/ppd/brmfc260c.ppd \
    && grep -q '^\*DefaultResolution: 600dpi$' /usr/share/cups-addon/ppd/brmfc260c.ppd

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

# Benutzer "print" für die Web-Administration (Passwort wird beim Start gesetzt)
RUN useradd \
        --groups=lp,lpadmin \
        --create-home \
        --home-dir=/home/print \
        --shell=/usr/sbin/nologin \
        print \
    && rm -f /etc/nginx/sites-enabled/default

COPY rootfs /

EXPOSE 631
