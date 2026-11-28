#!/bin/bash
# asc.sh: call the App Store Connect API from CI.
#   asc.sh GET /v1/apps/<id>/builds
#   asc.sh POST /v1/betaAppReviewSubmissions body.json
# Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_FILE (path to the .p8).
# Prints the response body, then the HTTP status on its own last line.
# The key itself is never printed: only openssl reads it.
set -euo pipefail

: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_FILE:?}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

token() {
  local now header payload signing sig
  now=$(date +%s)
  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
  payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' \
    "$ASC_ISSUER_ID" "$now" $((now + 1200)) | b64url)
  signing="$header.$payload"
  # openssl emits a DER ECDSA signature; JWS wants raw r||s (32 bytes each).
  sig=$(printf '%s' "$signing" | openssl dgst -sha256 -sign "$ASC_KEY_FILE" | python3 -I -c '
import sys, base64
d = sys.stdin.buffer.read()
i = 2 if d[1] < 0x80 else 3
def read_int(i):
    assert d[i] == 2
    n = d[i + 1]
    return d[i + 2:i + 2 + n], i + 2 + n
r, i = read_int(i)
s, i = read_int(i)
raw = r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0")
print(base64.urlsafe_b64encode(raw).rstrip(b"=").decode())
')
  printf '%s.%s' "$signing" "$sig"
}

method="${1:?usage: asc.sh METHOD PATH [BODY_FILE]}"
path="${2:?usage: asc.sh METHOD PATH [BODY_FILE]}"
body="${3:-}"
[[ "$path" == http* ]] || path="https://api.appstoreconnect.apple.com$path"

args=(-sS -g -X "$method" -H "Authorization: Bearer $(token)" -w '\n%{http_code}\n')
[[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' --data-binary "@$body")
curl "${args[@]}" "$path"
