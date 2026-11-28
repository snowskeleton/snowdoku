#!/bin/bash
# testflight.sh <build number>: after an upload, wait for App Store Connect to
# process the build, then give it to external testers: add it to the external
# group and submit it for beta app review. Internal testers get every build
# automatically. Uses asc.sh (same environment variables).
set -euo pipefail

BUILD="${1:?usage: testflight.sh <build number>}"
APP_ID=6839805704                                   # Snowdoku
EXTERNAL_GROUP=c5011a94-47c7-4885-9ec5-e6ca22a70917 # "All Users - External"
ASC="$(dirname "$0")/asc.sh"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"

# Body and status of an asc.sh call, split.
call() {
  local out; out=$("$ASC" "$@")
  STATUS=$(tail -n1 <<<"$out")
  BODY=$(sed '$d' <<<"$out")
}

json() { python3 -I -c "import sys, json; d = json.load(sys.stdin); print($1)" <<<"$BODY"; }

# Processing usually takes a minute or two; give up after 30 minutes.
for _ in $(seq 1 60); do
  call GET "/v1/builds?filter[app]=$APP_ID&filter[version]=$BUILD&filter[preReleaseVersion.platform]=IOS&fields[builds]=processingState"
  if [[ "$STATUS" == 200 ]]; then
    STATE=$(json 'd["data"][0]["attributes"]["processingState"] if d["data"] else "MISSING"')
    echo "build $BUILD: $STATE"
    case "$STATE" in
      VALID) BUILD_ID=$(json 'd["data"][0]["id"]'); break ;;
      FAILED|INVALID) echo "::error::App Store Connect rejected build $BUILD ($STATE)"; exit 1 ;;
    esac
  else
    echo "lookup returned HTTP $STATUS, retrying"
  fi
  sleep 30
done
[[ -n "${BUILD_ID:-}" ]] || { echo "::error::build $BUILD still not processed after 30 minutes"; exit 1; }

printf '{"data":[{"type":"betaGroups","id":"%s"}]}' "$EXTERNAL_GROUP" > "$TMP/group.json"
call POST "/v1/builds/$BUILD_ID/relationships/betaGroups" "$TMP/group.json"
[[ "$STATUS" == 204 ]] || { echo "::error::adding the external group failed (HTTP $STATUS): $BODY"; exit 1; }
echo "added to All Users - External"

printf '{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":{"data":{"type":"builds","id":"%s"}}}}}' "$BUILD_ID" > "$TMP/review.json"
call POST /v1/betaAppReviewSubmissions "$TMP/review.json"
[[ "$STATUS" == 201 ]] || { echo "::error::beta review submission failed (HTTP $STATUS): $BODY"; exit 1; }
echo "submitted for beta review: $(json 'd["data"]["attributes"]["betaReviewState"]')"
