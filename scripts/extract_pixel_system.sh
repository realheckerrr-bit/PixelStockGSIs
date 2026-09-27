#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE="${1:-}"
WORK_DIR="${2:-}"
OUTPUT_IMAGE="${3:-}"

if [ -z "$PACKAGE" ] || [ -z "$WORK_DIR" ] || [ -z "$OUTPUT_IMAGE" ] || [ ! -f "$PACKAGE" ]; then
  echo "usage: $0 <factory-or-ota-package> <work-dir> <output-system-img>" >&2
  exit 2
fi

EXTRACT_DIR="$WORK_DIR/pixel-package"
rm -rf -- "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR" "$(dirname "$OUTPUT_IMAGE")"

echo "==> [EXTRACT] Expanding Google package"
unzip -oq "$PACKAGE" -d "$EXTRACT_DIR" 2>/dev/null \
  || 7z x -y "$PACKAGE" -o"$EXTRACT_DIR" >/dev/null

# Factory packages contain an image-*.zip nested inside the outer factory zip.
# OTA packages usually contain payload.bin. Expand nested ZIPs a few levels so
# both official Google package layouts use the same discovery path.
for pass in 1 2 3; do
  while IFS= read -r -d '' zip_file; do
    destination="${zip_file}.expanded"
    [ -d "$destination" ] && continue
    mkdir -p "$destination"
    if unzip -oq "$zip_file" -d "$destination" 2>/dev/null \
      || 7z x -y "$zip_file" -o"$destination" >/dev/null 2>&1; then
      echo "    Expanded: $(basename "$zip_file")"
    else
      echo "[-] Failed to expand nested ZIP: $zip_file" >&2
      exit 1
    fi
  done < <(find "$EXTRACT_DIR" -type f -iname '*.zip' -print0)
done

SYSTEM_IMAGE=$(find "$EXTRACT_DIR" -type f \( -iname 'system.img' -o -iname 'system_a.img' \) \
  -printf '%s\t%p\n' | sort -nr | cut -f2- | head -n 1)

# Full OTA images use payload.bin. payload-dumper-go is installed by the
# workflow and emits the logical partition images without touching boot/vendor.
if [ -z "$SYSTEM_IMAGE" ]; then
  PAYLOAD="$(find "$EXTRACT_DIR" -type f -name payload.bin -print -quit)"
  if [ -n "$PAYLOAD" ]; then
    PAYLOAD_OUT="$WORK_DIR/payload-out"
    mkdir -p "$PAYLOAD_OUT"
    echo "==> [EXTRACT] Expanding OTA payload.bin"
    payload-dumper-go -o "$PAYLOAD_OUT" "$PAYLOAD"
    SYSTEM_IMAGE="$(find "$PAYLOAD_OUT" -type f \( -iname 'system.img' -o -iname 'system_a.img' \) -print -quit)"
  fi
fi

if [ -z "$SYSTEM_IMAGE" ] || [ ! -f "$SYSTEM_IMAGE" ]; then
  echo "[-] No system.img was found in the official Google package." >&2
  find "$EXTRACT_DIR" -maxdepth 3 -type f | sort | head -n 100 >&2 || true
  exit 1
fi

IMAGE_TYPE=$(file -b "$SYSTEM_IMAGE" | tr '[:upper:]' '[:lower:]')
if ! printf '%s' "$IMAGE_TYPE" | grep -Eiq 'android sparse|filesystem|data'; then
  echo "[-] Discovered system image has an unexpected type: $IMAGE_TYPE" >&2
  exit 1
fi
cp -- "$SYSTEM_IMAGE" "$OUTPUT_IMAGE"
printf '%s\n' "$SYSTEM_IMAGE" > "$WORK_DIR/source-system-path.txt"
printf '%s\n' "$IMAGE_TYPE" > "$WORK_DIR/source-system-type.txt"
printf '%s\n' "$(sha256sum "$OUTPUT_IMAGE" | cut -d' ' -f1)" > "$WORK_DIR/source-system.sha256"
echo "==> [EXTRACT] Selected: $SYSTEM_IMAGE"
echo "    Type: $IMAGE_TYPE"
