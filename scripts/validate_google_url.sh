#!/usr/bin/env bash
set -Eeuo pipefail

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: $0 <https-google-download-url>" >&2
  exit 2
fi

python3 - "$URL" <<'PY'
import sys
from urllib.parse import urlparse

url = sys.argv[1]
parsed = urlparse(url)
allowed = {
    "dl.google.com",
    "storage.googleapis.com",
    "android.googleapis.com",
    "ota.googlezip.net",
}

if parsed.scheme != "https":
    raise SystemExit("[-] Google image URL must use HTTPS")
if parsed.username or parsed.password or not parsed.hostname:
    raise SystemExit("[-] Google image URL must not contain credentials")
host = parsed.hostname.lower().rstrip(".")
if host not in allowed:
    raise SystemExit("[-] URL host is not an approved Google image host: " + host)
if not parsed.path or parsed.path == "/":
    raise SystemExit("[-] Google image URL has no download path")
print(url)
PY
