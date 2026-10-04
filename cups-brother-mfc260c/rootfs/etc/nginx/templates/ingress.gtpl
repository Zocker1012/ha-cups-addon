# Ingress-Proxy: Home Assistant -> Web-Oberfläche auf Port 631
# (CUPS im Modus "cups", Legacy Printer Application im Modus "printer_app")
#
# Beide Oberflächen verwenden absolute Pfade ("/admin", "/style.css" ...).
# Unter Ingress liegt die Oberfläche aber unter {{ .entry }}/, daher werden
# Links, Formulare und Weiterleitungen umgeschrieben.

server {
    listen {{ .port }} default_server;

    # Nur der Ingress-Proxy des Supervisors darf zugreifen
    allow 172.30.32.2;
    deny all;

    client_max_body_size 256M;
    proxy_read_timeout   300s;

    location / {
        proxy_pass         http://127.0.0.1:631;
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

        proxy_redirect     http://localhost:631/  {{ .entry }}/;
        proxy_redirect     https://localhost:631/ {{ .entry }}/;
        proxy_redirect     /                      {{ .entry }}/;

        sub_filter_types   text/css text/javascript application/javascript;
        sub_filter_once    off;
        sub_filter         'http://localhost:631/'  '{{ .entry }}/';
        sub_filter         'https://localhost:631/' '{{ .entry }}/';
        sub_filter         'href="/'   'href="{{ .entry }}/';
        sub_filter         'src="/'    'src="{{ .entry }}/';
        sub_filter         'action="/' 'action="{{ .entry }}/';
        sub_filter         'url(/'     'url({{ .entry }}/';
        sub_filter         'URL=/'     'URL={{ .entry }}/';
        sub_filter         "href='/"   "href='{{ .entry }}/";
        sub_filter         "action='/" "action='{{ .entry }}/";
    }
}
