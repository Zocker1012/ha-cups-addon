ARG BUILD_FROM
FROM ${BUILD_FROM}

LABEL \
  io.hass.version="1.0.0" \
  io.hass.type="addon" \
  io.hass.arch="amd64"

# Shell konfigurieren
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# 32-Bit Architektur aktivieren und Pakete installieren
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        cups \
        cups-filters \
        cups-pdf \
        avahi-daemon \
        libnss-mdns \
        dbus \
        ghostscript \
        perl \
        nginx \
        # 32-Bit Laufzeit-Bibliotheken für Brother i386-Treiber
        libc6:i386 \
        libstdc++6:i386 \
        zlib1g:i386 \
        lib32z1 \
        libusb-0.1-4:i386 \
        libusb-1.0-0:i386 \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Brother MFC-260C Treiber aus dem Repo installieren
COPY drivers/ /tmp/drivers/

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        /tmp/drivers/mfc260clpr-1.0.1-1.i386.deb \
        /tmp/drivers/mfc260ccupswrapper-1.0.1-1.i386.deb \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN if [ -d /usr/lib/cups/filter ]; then \
         find /usr/lib/cups/filter -maxdepth 1 -type f \
           \( -name 'br*' -o -name '*mfc260c*' \) \
           -exec chmod 0755 {} \; ; \
       fi \
    && if [ -d /opt/brother ]; then \
         find /opt/brother -type f \
           \( -name '*.sh' -o -name '*wrapper*' -o -name '*filter*' \
              -o -name 'brprintconflsr3' -o -name 'rawtobr3' \) \
           -exec chmod 0755 {} \; ; \
       fi \
    && mkdir -p /var/spool/lpd/mfc260c \
    && chmod 1777 /var/spool/lpd /var/spool/lpd/mfc260c \
    && rm -rf /tmp/drivers

# rootfs ins Image-Dateisystem übernehmen
COPY rootfs /

# Benutzer "print" für CUPS Web-UI anlegen
RUN useradd \
    --groups=lp,lpadmin \
    --create-home \
    --home-dir=/home/print \
    --shell=/bin/bash \
    --password=$(openssl passwd -6 print) \
    print 

RUN rm -f /etc/nginx/sites-enabled/default

EXPOSE 631
