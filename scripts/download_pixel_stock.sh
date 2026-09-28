#!/usr/bin/env bash
set -Eeuo pipefail

URL="${1:-}"
DEST="${2:-}"
EXPECTED_SHA256="${3:-}"

if [ -z "$URL" ] || [ -z "$DEST" ] || [ -z "$EXPECTED_SHA256" ]; then
  echo "usage: $0 <official-google-url> <destination> <sha256>" >&2
  exit 2
fi
if ! [[ "$EXPECTED_SHA256" =~ ^[0-9A-Fa-f]{64}$ ]]; then
  echo "[-] SHA-256 must be exactly 64 hexadecimal characters." >&2
  exit 2
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
VALIDATED_URL=$(bash "$SCRIPT_DIR/validate_google_url.sh" "$URL")
mkdir -p "$(dirname "$(realpath "$DEST")")"

echo "==> [DOWNLOAD] Downloading official Google package"
echo "    Host: $(python3 -c 'from urllib.parse import urlparse; import sys; print(urlparse(sys.argv[1]).hostname)' "$VALIDATED_URL")"
curl --fail --location --proto '=https' --tlsv1.2 \
  --retry 5 --retry-all-errors --retry-delay 5 \
  --connect-timeout 30 --max-time 3600 \
  -o "$DEST" "$VALIDATED_URL"

if [ ! -s "$DEST" ]; then
  echo "[-] Google download is empty." >&2
  exit 1
fi
if file -b "$DEST" | grep -Eiq 'html document|empty'; then
  echo "[-] Google download returned HTML/empty content, not a firmware package." >&2
  exit 1
fi

echo "==> [DOWNLOAD] Verifying SHA-256"
printf '%s  %s\n' "$EXPECTED_SHA256" "$DEST" | sha256sum --check --status
echo "    SHA-256: $EXPECTED_SHA256"
printf '%s\n' "$VALIDATED_URL" > "${DEST}.url"
printf '%s\n' "$EXPECTED_SHA256" > "${DEST}.sha256"
