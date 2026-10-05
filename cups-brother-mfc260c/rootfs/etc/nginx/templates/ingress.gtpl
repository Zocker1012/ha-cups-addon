# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Zocker1012
# Ingress-Proxy: Home Assistant -> Weboberflächen des Add-ons
#
#   /          Startseite (Drucker, Scanner, Adressen)
#   /printer/  CUPS (Modus "cups") oder Legacy Printer Application auf Port 631
#   /scan/     AirSane (Scanner) auf Port 8090
#
# Die Oberflächen verwenden absolute Pfade ("/admin", "/style.css" ...).
# Unter Ingress liegen sie aber unter {{ .entry }}/..., daher werden Links,
# Formulare und Weiterleitungen umgeschrieben.

server {
    listen {{ .port }} default_server;

    # Nur der Ingress-Proxy des Supervisors darf zugreifen
    allow 172.30.32.2;
    deny all;

    client_max_body_size 256M;
    proxy_read_timeout   300s;
    absolute_redirect    off;

    location = / {
        root      /usr/share/cups-addon/www;
        try_files /index.html =404;
    }

    location = /printer {
        return 302 {{ .entry }}/printer/;
    }

    location /printer/ {
        proxy_pass         http://127.0.0.1:631/;
        proxy_http_version 1.1;
        proxy_set_header   Host            localhost:631;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;

        # Home Assistant hat den Benutzer bereits authentifiziert: als interner
        # Benutzer "ingress" (zufälliges Token pro Start) bei CUPS bzw. der
        # Printer Application anmelden
        proxy_set_header   Authorization   "Basic {{ .auth }}";
        # Printer Application: Login-Cookie (wird von ingress-session.sh gepflegt)
        include            /run/cups-addon/ingress-cookie.conf;

        # Unkomprimierte Antworten, damit sub_filter greift
        proxy_set_header   Accept-Encoding "";

        # Einbettung in die HA-Oberfläche (iframe) erlauben
        proxy_hide_header  X-Frame-Options;
        proxy_hide_header  Content-Security-Policy;

        # Die Printer Application setzt Cookies immer mit "secure" – das würde
        # bei Home Assistant über reines HTTP verworfen
        proxy_cookie_flags ~ nosecure;

        proxy_redirect     http://localhost:631/  {{ .entry }}/printer/;
        proxy_redirect     https://localhost:631/ {{ .entry }}/printer/;
        proxy_redirect     /                      {{ .entry }}/printer/;

        sub_filter_types   text/css text/javascript application/javascript;
        sub_filter_once    off;
        sub_filter         'http://localhost:631/'  '{{ .entry }}/printer/';
        sub_filter         'https://localhost:631/' '{{ .entry }}/printer/';
        sub_filter         'href="/'   'href="{{ .entry }}/printer/';
        sub_filter         'src="/'    'src="{{ .entry }}/printer/';
        sub_filter         'action="/' 'action="{{ .entry }}/printer/';
        sub_filter         'url(/'     'url({{ .entry }}/printer/';
        sub_filter         'URL=/'     'URL={{ .entry }}/printer/';
        sub_filter         "href='/"   "href='{{ .entry }}/printer/";
        sub_filter         "action='/" "action='{{ .entry }}/printer/";
    }
{{- if .scanner }}

    location = /scan {
        return 302 {{ .entry }}/scan/;
    }

    location /scan/ {
        proxy_pass         http://127.0.0.1:8090/;
        proxy_http_version 1.1;
        proxy_set_header   Host            localhost:8090;
        proxy_set_header   Accept-Encoding "";
        proxy_hide_header  X-Frame-Options;
        proxy_hide_header  Content-Security-Policy;
        # Scans können dauern
        proxy_read_timeout 600s;
        proxy_buffering    off;

        proxy_redirect     http://localhost:8090/ {{ .entry }}/scan/;
        proxy_redirect     /                      {{ .entry }}/scan/;

        sub_filter_types   text/css text/javascript application/javascript;
        sub_filter_once    off;
        sub_filter         'http://localhost:8090/' '{{ .entry }}/scan/';
        sub_filter         'href="/'   'href="{{ .entry }}/scan/';
        sub_filter         'src="/'    'src="{{ .entry }}/scan/';
        sub_filter         'action="/' 'action="{{ .entry }}/scan/';
        sub_filter         "href='/"   "href='{{ .entry }}/scan/";
        sub_filter         "src='/"    "src='{{ .entry }}/scan/";
        sub_filter         "action='/" "action='{{ .entry }}/scan/";
        sub_filter         'url(/'     'url({{ .entry }}/scan/';
    }
{{- end }}
}
