# Prüf-Video 1.2 — Drehbuch

Kurzes Bildschirmvideo für die App-Prüfung von Version 1.2. **Für ein normales
Update verlangt Apple kein Video** — wir legen es wie bei 1.1 proaktiv in die
Prüf-Notizen, damit die neuen Funktionen (Dokument aus Text erstellen, `.txt`)
ohne Rückfrage (Guideline 2.1) nachvollziehbar sind.

## Rahmen

- **Gerät:** physisches iPhone (Simulator-Aufnahmen akzeptiert Apple ungern).
- **Aufnahme:** Kontrollzentrum → Bildschirmaufnahme. Ton aus.
- **Länge:** 45–60 s. Ruhig, jede Aktion 1 s halten.
- **Vorbereitung:**
  - `Notiz-Entwurf.txt` und eine `.md`-Demo (z. B. `Team-Notiz.md`) aus
    `App-Store-Screenshots/demo-dokumente/` per AirDrop auf das iPhone, in
    „Dateien" → „Auf meinem iPhone" ablegen.
  - In einer Notiz-App einen kurzen Text kopieren (z. B. „# Einkauf\n\n- Kaffee\n- Brot").
  - md Viewer 1.2 (Build 10) aus TestFlight installiert.

## Schritte

1. **Start.** md Viewer öffnen → Leerzustand mit „Einsetzen" und „Leeres Dokument".
2. **Aus Zwischenablage.** „Einsetzen" tippen → der kopierte Text öffnet sofort
   formatiert im Editor („Neues Dokument").
3. **Bearbeiten.** Eine Zeile ergänzen, z. B. `- Milch`.
4. **Als .md sichern.** Roten Haken tippen → System-Speicherdialog → Ordner
   wählen → Name vergeben → sichern. Kurz zeigen, dass die Datei in „Dateien"
   liegt.
5. **Erneut öffnen + in place speichern.** Datei aus „Dateien" öffnen → erscheint
   formatiert → „Bearbeiten" → eine Zeile ändern → roter Haken → Rückfrage
   bestätigen → Original ist überschrieben.
6. **.txt öffnen.** `Notiz-Entwurf.txt` über „Öffnen mit → md Viewer" (oder das
   Teilen-Menü) öffnen → wird als Markdown gerendert.
7. **Als Markdown speichern.** In der `.txt` „Bearbeiten" → Toolbar-Überlauf →
   „Als Markdown speichern" → als `.md` sichern.
8. **Leeres Dokument (optional, wenn Zeit).** Zurück zum Leerzustand → „Leeres
   Dokument" → ein, zwei Zeilen tippen → als `.md` sichern.

## Nachbearbeitung

- Auf < 50 MB komprimieren (wie 1.1: `ffmpeg -i in.mov -vcodec h264 -crf 30 -vf scale=-2:1280 out.mp4`).
- Ablegen als `docs/apple-review-video-1.2.mp4`.
- In ASC an das App-Prüfungs-Anmerkungen-Feld hängen; zusätzlich
  `docs/sample-markdown-files.zip` (die `.md`-Demos + `Notiz-Entwurf.txt`)
  anhängen — einzelne `.md`/`.txt` sind kein zulässiger Anhangstyp, `.zip` schon.
