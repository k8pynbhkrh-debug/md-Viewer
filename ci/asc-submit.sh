#!/bin/bash
#
# Reicht EINE vorbereitete App-Store-Version zur Prüfung ein (App Store Connect
# API: reviewSubmissions). Bewusst schmal gehalten, damit eine Berechtigungsregel
# `Bash(ci/asc-submit.sh *)` genau diese eine Aktion freigibt und nichts sonst.
#
# Aufruf:
#   ci/asc-submit.sh <appStoreVersion-id> [--dry-run]
#
# Vertrag
#   Vorbedingungen (alle vor dem ersten schreibenden Aufruf geprüft, sonst Abbruch):
#     - Version existiert, appStoreState == PREPARE_FOR_SUBMISSION
#     - an der Version hängt ein Build mit processingState == VALID
#     - alle Lokalisierungen der Version haben "whatsNew" gesetzt
#     - API-Key ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 vorhanden
#   Nachbedingung (nach Erfolg geprüft):
#     - Version steht auf WAITING_FOR_REVIEW
#   Invarianten:
#     - Mit --dry-run wird nichts geschrieben, nur die Vorbedingungen geprüft.
#     - Es wird nur diese eine Version eingereicht; Build, Texte und Release-Modus
#       (z. B. AFTER_APPROVAL) werden nicht verändert.
#
# Key-ID und Issuer-ID sind keine Geheimnisse (der Schlüssel selbst liegt im
# Schlüsselbund-Ordner); per Umgebungsvariable überschreibbar.

set -euo pipefail

KEY_ID="${ASC_KEY_ID:-62MR36Z6LR}"
ISSUER_ID="${ASC_ISSUER_ID:-8ba31218-10a2-4f2f-9780-63b789add5b7}"
APP_ID="${ASC_APP_ID:-6806814038}"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"

VERSION_ID="${1:-}"
DRY_RUN=0
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1
if [ -z "$VERSION_ID" ] || [[ "$VERSION_ID" == --* ]]; then
  echo "Aufruf: ci/asc-submit.sh <appStoreVersion-id> [--dry-run]" >&2 ; exit 2
fi
[ -f "$KEY_FILE" ] || { echo "Vorbedingung verletzt: API-Key fehlt: $KEY_FILE" >&2 ; exit 1; }

export KEY_ID ISSUER_ID APP_ID KEY_FILE VERSION_ID DRY_RUN

exec python3 - <<'PY'
import base64, json, os, subprocess, sys, time

KEY_ID, ISSUER, APP = os.environ["KEY_ID"], os.environ["ISSUER_ID"], os.environ["APP_ID"]
KEY_FILE, VID, DRY = os.environ["KEY_FILE"], os.environ["VERSION_ID"], os.environ["DRY_RUN"] == "1"
API = "https://api.appstoreconnect.apple.com"

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def jwt():
    head = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    body = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 900,
                           "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_FILE],
                         input=f"{head}.{body}".encode(), capture_output=True, check=True).stdout
    i = 2 if der[1] < 0x80 else 3                      # DER (r, s) -> raw r||s
    rl = der[i + 1]; r = der[i + 2:i + 2 + rl]; i += 2 + rl
    sl = der[i + 1]; s = der[i + 2:i + 2 + sl]
    raw = r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0")
    return f"{head}.{body}.{b64(raw)}"

TOKEN = jwt()

def call(method, path, body=None):
    # curl statt urllib: nutzt den System-Schlüsselbund für TLS (Homebrew-Python
    # hat keine CA-Zertifikate).
    cmd = ["curl", "-sS", "-X", method, API + path, "-w", "\n%{http_code}",
           "-H", f"Authorization: Bearer {TOKEN}", "-H", "Content-Type: application/json"]
    if body is not None:
        cmd += ["-d", json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"curl-Fehler bei {method} {path}: {out.stderr.strip()}")
    text, _, code = out.stdout.rpartition("\n")
    if not code.startswith("2"):
        sys.exit(f"API-Fehler {code} bei {method} {path}: {text[:600]}")
    return json.loads(text or "{}")

def fail(msg): sys.exit(f"Vorbedingung verletzt: {msg}")

# --- Vorbedingungen (nur lesend) -------------------------------------------
v = call("GET", f"/v1/appStoreVersions/{VID}")["data"]["attributes"]
label = f'{v["platform"]} {v["versionString"]}'
if v["appStoreState"] != "PREPARE_FOR_SUBMISSION":
    fail(f'{label} steht auf {v["appStoreState"]}, erwartet PREPARE_FOR_SUBMISSION')

build = call("GET", f"/v1/appStoreVersions/{VID}/build").get("data")
if not build:
    fail(f"{label}: kein Build angehängt")
if build["attributes"]["processingState"] != "VALID":
    fail(f'{label}: Build {build["attributes"]["version"]} ist {build["attributes"]["processingState"]}, nicht VALID')

for loc in call("GET", f"/v1/appStoreVersions/{VID}/appStoreVersionLocalizations")["data"]:
    if not (loc["attributes"].get("whatsNew") or "").strip():
        fail(f'{label}: whatsNew fehlt in {loc["attributes"]["locale"]}')

print(f'Vorbedingungen ok: {label}, Build {build["attributes"]["version"]} (VALID)')
if DRY:
    print("--dry-run: nichts eingereicht."); sys.exit(0)

# --- Einreichen ------------------------------------------------------------
sub = call("POST", "/v1/reviewSubmissions", {"data": {
    "type": "reviewSubmissions", "attributes": {"platform": v["platform"]},
    "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
call("POST", "/v1/reviewSubmissionItems", {"data": {
    "type": "reviewSubmissionItems", "relationships": {
        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VID}}}}})
call("PATCH", f"/v1/reviewSubmissions/{sub}", {"data": {
    "type": "reviewSubmissions", "id": sub, "attributes": {"submitted": True}}})

# --- Nachbedingung ---------------------------------------------------------
for _ in range(6):
    state = call("GET", f"/v1/appStoreVersions/{VID}")["data"]["attributes"]["appStoreState"]
    if state == "WAITING_FOR_REVIEW":
        print(f"Eingereicht: {label}, Submission {sub}, Status {state}"); sys.exit(0)
    time.sleep(2)
sys.exit(f"Nachbedingung verletzt: {label} steht auf {state}, erwartet WAITING_FOR_REVIEW (Submission {sub})")
PY
