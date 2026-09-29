# Abhängigkeiten

Stand: 29.09.2026 (T-2026-274). Bei jedem Update einer Abhängigkeit diese Datei
mitziehen: Version, Quelle, Hash bzw. Commit.

## Gebündelt als Datei

### Mermaid.js

| | |
|---|---|
| Datei | `md Viewer/md Viewer/Resources/mermaid.min.js` (3.337.857 Bytes) |
| Version | 10.9.8 |
| Quelle | npm-Paket `mermaid@10.9.8`, Datei `dist/mermaid.min.js` — z. B. `https://cdn.jsdelivr.net/npm/mermaid@10.9.8/dist/mermaid.min.js` |
| SHA-256 | `8d607d7ef1d077a8aa202e18e62212bfa992c68bfeabc5cf45d51a128fe6675d` |
| Lizenz | MIT; enthält DOMPurify 3.4.2 (Apache 2.0 / MPL 2.0) |
| Eingebunden | T-2026-006 (15.09.2026) |
| Genutzt von | `MermaidRenderer.swift` (nur Haupt-App, nicht die Share Extension) |

Der Hash wurde am 29.09.2026 gegen jsDelivr und unpkg geprüft, beide sind byte-gleich.
So prüfst du ihn erneut:

```sh
shasum -a 256 "md Viewer/md Viewer/Resources/mermaid.min.js"
curl -s https://cdn.jsdelivr.net/npm/mermaid@10.9.8/dist/mermaid.min.js | shasum -a 256
```

Sicherheitsrahmen um die Bibliothek (`MermaidRenderer.swift`): CSP `default-src 'none'`,
`securityLevel: 'strict'`, Navigationssperre außer der lokalen Harness-Seite,
max. 20.000 Zeichen Quelltext und max. 4096 pt/px Grafik. Dazu Timeouts: 20 s fürs
Laden der Seite, 5 s pro Diagramm. Nach einem Mermaid-Update laufen
`MermaidRendererTests` und die Mermaid-Punkte in `docs/release-checkliste.md`.

## Swift Package Manager

Die Versionen sind in `Package.resolved` gepinnt. Übersicht:

| Paket | Version | Quelle |
|---|---|---|
| swift-markdown-ui | 2.4.1 | https://github.com/gonzalezreal/swift-markdown-ui |
| swift-cmark | 0.8.0 | https://github.com/swiftlang/swift-cmark |
| NetworkImage | 6.0.1 | https://github.com/gonzalezreal/NetworkImage (transitiv über MarkdownUI; md Viewer nutzt eigene Image-Provider und lädt darüber nichts) |
| Highlightr | 2.3.0 | https://github.com/raspu/Highlightr |
