#!/bin/bash
# whats-new.sh <build id> <notes file>: set a TestFlight build's "What to Test"
# (en-US), updating its localization or creating one. Uses asc.sh (same
# environment variables). <build id> is App Store Connect's id, not the number.
set -euo pipefail

BUILD_ID="${1:?usage: whats-new.sh <build id> <notes file>}"
NOTES="${2:?usage: whats-new.sh <build id> <notes file>}"
ASC="$(dirname "$0")/asc.sh"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"

call() {
  local out; out=$("$ASC" "$@")
  STATUS=$(tail -n1 <<<"$out")
  BODY=$(sed '$d' <<<"$out")
}

call GET "/v1/builds/$BUILD_ID/betaBuildLocalizations"
[[ "$STATUS" == 200 ]] || { echo "::error::reading the build's localizations failed (HTTP $STATUS): $BODY"; exit 1; }
LOC_ID=$(python3 -I -c 'import sys, json; d = json.load(sys.stdin); print(next((l["id"] for l in d["data"] if l["attributes"]["locale"] == "en-US"), ""))' <<<"$BODY")

# TestFlight allows 4000 characters.
python3 -I - "$NOTES" "$BUILD_ID" "$LOC_ID" > "$TMP/notes.json" <<'PY'
import json, sys
notes, build, loc = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(notes, encoding="utf-8").read().strip()[:4000]
if loc:
    body = {"data": {"type": "betaBuildLocalizations", "id": loc, "attributes": {"whatsNew": text}}}
else:
    body = {"data": {"type": "betaBuildLocalizations",
                     "attributes": {"locale": "en-US", "whatsNew": text},
                     "relationships": {"build": {"data": {"type": "builds", "id": build}}}}}
print(json.dumps(body))
PY

if [[ -n "$LOC_ID" ]]; then
  call PATCH "/v1/betaBuildLocalizations/$LOC_ID" "$TMP/notes.json"; want=200
else
  call POST /v1/betaBuildLocalizations "$TMP/notes.json"; want=201
fi
[[ "$STATUS" == "$want" ]] || { echo "::error::setting What to Test failed (HTTP $STATUS): $BODY"; exit 1; }
echo "set What to Test"
