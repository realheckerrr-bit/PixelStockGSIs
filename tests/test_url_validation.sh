#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
VALIDATOR="$ROOT_DIR/scripts/validate_google_url.sh"

bash "$VALIDATOR" "https://dl.google.com/dl/android/aosp/example-factory.zip" >/dev/null
bash "$VALIDATOR" "https://storage.googleapis.com/pixel-images/example-ota.zip" >/dev/null

if bash "$VALIDATOR" "https://example.com/pixel.zip" >/dev/null 2>&1; then
  echo "[-] Non-Google host was accepted." >&2
  exit 1
fi
if bash "$VALIDATOR" "http://dl.google.com/pixel.zip" >/dev/null 2>&1; then
  echo "[-] HTTP URL was accepted." >&2
  exit 1
fi

echo "==> Google URL validation tests passed."
