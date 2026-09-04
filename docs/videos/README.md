# Prüf-Videos für die App-Prüfung

Kurze Bildschirmaufnahmen, die wir Apple proaktiv in die Prüf-Notizen legen,
damit neue/heikle Funktionen ohne Rückfrage (Guideline 2.1) nachvollziehbar sind.
Komprimierte Fassungen (h264, ~1280 px hoch, ohne Ton) sind eingecheckt; die
Roh-Aufnahmen liegen in `roh/` (gitignored).

| Datei | Version | Inhalt |
|---|---|---|
| `2026-08-31_v1.0_pruefung_oeffnen-und-teilen-extension.mp4` | 1.0 | Antwort auf Guideline 2.1: App vom Home starten, `.md` per „Öffnen mit" rendern, `.md` per Teilen-Menü → Share-Extension rendert inline → „Fertig". Read-only-Viewer, keine Logins. |
| `2026-09-03_v1.1_pruefung_bearbeiten-und-speichern.mp4` | 1.1 | Edit-Modus: `.md` öffnen → „Bearbeiten" → Text ändern → roter Haken → Rückfrage → Originaldatei überschrieben. |
| `2026-09-04_v1.2_pruefung_neues-dokument-und-txt.mp4` | 1.2 | Ohne Datei anfangen: „Einsetzen" (System-PasteButton) → Entwurf im Editor → „Als .md sichern" → Datei erneut öffnen + in place speichern → `.txt` öffnen → „Als Markdown speichern". |

## Neues Video erstellen

Drehbuch/Ablauf: `../apple-review-video-1.2-anleitung.md` (als Vorlage).
Komprimieren:

```
ffmpeg -y -i roh/<datei>.MP4 -vcodec h264 -crf 30 -vf "scale=-2:1280" -an \
  "<JJJJ-MM-TT>_v<version>_pruefung_<kurzbeschreibung>.mp4"
```
