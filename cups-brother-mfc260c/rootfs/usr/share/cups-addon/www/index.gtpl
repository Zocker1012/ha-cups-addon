<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Brother MFC-260C</title>
  <style>
    :root {
      --bg: #f5f6f8;
      --card: #ffffff;
      --text: #1f2328;
      --muted: #59636e;
      --accent: #2176ff;
      --border: #d8dee4;
      --code: #eef1f4;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #111318;
        --card: #1c1f26;
        --text: #e6e8eb;
        --muted: #9aa4b0;
        --border: #2d333b;
        --code: #262b33;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px 16px;
      background: var(--bg);
      color: var(--text);
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    }
    main { max-width: 720px; margin: 0 auto; }
    header { display: flex; align-items: center; gap: 14px; margin-bottom: 24px; }
    header svg { width: 48px; height: 48px; flex: none; }
    h1 { font-size: 1.4rem; margin: 0; }
    header p { margin: 2px 0 0; color: var(--muted); }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; }
    a.card {
      display: flex;
      align-items: center;
      gap: 16px;
      padding: 20px;
      border: 1px solid var(--border);
      border-radius: 12px;
      background: var(--card);
      color: inherit;
      text-decoration: none;
    }
    a.card:hover, a.card:focus-visible { border-color: var(--accent); outline: none; }
    a.card svg { width: 56px; height: 56px; flex: none; }
    h2 { font-size: 1.1rem; margin: 0 0 4px; }
    a.card p { margin: 0; color: var(--muted); font-size: 0.95rem; }
    section {
      margin-top: 24px;
      padding: 20px;
      border: 1px solid var(--border);
      border-radius: 12px;
      background: var(--card);
    }
    section h2 { margin-bottom: 12px; }
    .row { display: grid; grid-template-columns: 9.5rem 1fr auto; align-items: center; gap: 8px 12px; padding: 6px 0; }
    .row span { color: var(--muted); }
    code {
      padding: 6px 8px;
      border-radius: 6px;
      background: var(--code);
      font-size: 0.9rem;
      overflow-wrap: anywhere;
    }
    button {
      padding: 6px 10px;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: transparent;
      color: var(--text);
      font: inherit;
      font-size: 0.85rem;
      cursor: pointer;
    }
    button:hover { border-color: var(--accent); }
    section p { margin: 12px 0 0; color: var(--muted); font-size: 0.9rem; }
    @media (max-width: 480px) {
      .row { grid-template-columns: 1fr auto; }
      .row span { grid-column: 1 / -1; }
      code { font-size: 0.8rem; }
    }
  </style>
</head>
<body>
  <!-- Symbole: Drucker (wie das Add-on-Symbol) und Scanner mit geöffnetem Deckel -->
  <svg width="0" height="0" style="position:absolute" aria-hidden="true">
    <symbol id="printer" viewBox="0 0 128 128">
      <rect width="128" height="128" rx="24" fill="#2176ff"/>
      <rect x="30" y="26" width="68" height="10" rx="3" fill="#fff"/>
      <rect x="20" y="40" width="88" height="44" rx="8" fill="#fff"/>
      <rect x="34" y="74" width="60" height="6" fill="#2176ff"/>
      <rect x="40" y="80" width="48" height="24" fill="#fff"/>
      <rect x="46" y="86" width="36" height="2.5" fill="#2176ff"/>
      <rect x="46" y="92" width="36" height="2.5" fill="#2176ff"/>
      <rect x="46" y="98" width="24" height="2.5" fill="#2176ff"/>
      <circle cx="96" cy="54" r="4" fill="#2176ff"/>
    </symbol>
    <symbol id="scanner" viewBox="0 0 128 128">
      <rect width="128" height="128" rx="24" fill="#2176ff"/>
      <rect x="22" y="56" width="82" height="9" rx="3" fill="#fff" transform="rotate(-30 24 61)"/>
      <rect x="20" y="66" width="88" height="34" rx="8" fill="#fff"/>
      <rect x="30" y="74" width="68" height="4" rx="2" fill="#2176ff"/>
      <circle cx="96" cy="89" r="4" fill="#2176ff"/>
    </symbol>
  </svg>

  <main>
    <header>
      <svg role="img" aria-label="Add-on-Symbol"><use href="#printer"/></svg>
      <div>
        <h1>Brother MFC-260C</h1>
        <p>Drucken und Scannen im Heimnetz</p>
      </div>
    </header>

    <div class="grid">
      <a class="card" href="printer/">
        <svg aria-hidden="true"><use href="#printer"/></svg>
        <div>
          <h2>Drucker</h2>
          <p>Aufträge, Papier, Qualität, Verwaltung</p>
        </div>
      </a>
{{- if .scanner }}
      <a class="card" href="scan/">
        <svg aria-hidden="true"><use href="#scanner"/></svg>
        <div>
          <h2>Scanner</h2>
          <p>Im Browser scannen und herunterladen</p>
        </div>
      </a>
{{- end }}
    </div>

    <section>
      <h2>Geräte verbinden</h2>
      <div class="row">
{{- if eq .mode "cups" }}
        <span>Drucker (CUPS)</span><code>http://{{ .ip }}:631/printers/</code>
{{- else }}
        <span>Drucker (IPP)</span><code>ipp://{{ .ip }}:631/ipp/print</code>
{{- end }}
        <button type="button">Kopieren</button>
      </div>
{{- if .scanner }}
      <div class="row">
        <span>Scanner (eSCL)</span><code>http://{{ .ip }}:8090/</code>
        <button type="button">Kopieren</button>
      </div>
{{- end }}
{{- if .scan_smb }}
      <div class="row">
        <span>Scan-Ordner</span><code>{{ .scan_smb }}</code>
        <button type="button">Kopieren</button>
      </div>
{{- end }}
{{- if .print_smb }}
      <div class="row">
        <span>Druckordner</span><code>{{ .print_smb }}</code>
        <button type="button">Kopieren</button>
      </div>
{{- end }}
      <p>Meist finden Geräte Drucker und Scanner von selbst. Die Adressen
        brauchst du nur, wenn nicht. Ordner sind mit dem Add-on „Samba share“
        erreichbar.</p>
    </section>
  </main>

  <script>
    // Kopieren, auch ohne HTTPS (dort fehlt navigator.clipboard)
    for (const button of document.querySelectorAll(".row button")) {
      button.addEventListener("click", async () => {
        const text = button.previousElementSibling.textContent;
        try {
          await navigator.clipboard.writeText(text);
        } catch {
          const area = document.createElement("textarea");
          area.value = text;
          document.body.append(area);
          area.select();
          document.execCommand("copy");
          area.remove();
        }
        button.textContent = "Kopiert";
        setTimeout(() => { button.textContent = "Kopieren"; }, 1500);
      });
    }
  </script>
</body>
</html>
