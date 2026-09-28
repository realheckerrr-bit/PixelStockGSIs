#!/usr/bin/env bash
set -Eeuo pipefail

GOOGLE_URL="${1:-}"
REQUESTED_NAME="${2:-PixelStockGSI}"
FS_TYPE="${3:-ext4}"
WORK_DIR="${4:-$(pwd)/workspace}"
EXPECTED_SHA256="${5:-}"
TARGET_MODEL="${6:-generic}"
EXPECTED_ARCH="${7:-arm64}"
SOURCE_MODE="${8:-pixel_stock}"
DOWNLOAD_DEVICE_HINT="${9:-}"
TARGET_PROPERTIES_FILE="${10:-}"

if [ -z "$GOOGLE_URL" ] || [ -z "$EXPECTED_SHA256" ]; then
  echo "usage: $0 <official-google-url> <name> <ext4|erofs> <work-dir> <sha256> [target-model] [arm64|arm|a64|auto] [pixel_stock|official_gsi] [download-device-hint] [target-properties-file]" >&2
  exit 2
fi
case "$FS_TYPE" in ext4|erofs) ;; *) echo "[-] filesystem must be ext4 or erofs" >&2; exit 2 ;; esac
case "$EXPECTED_ARCH" in arm64|arm|a64|auto) ;; *) echo "[-] invalid ABI profile" >&2; exit 2 ;; esac
case "$SOURCE_MODE" in pixel_stock|official_gsi) ;; *) echo "[-] invalid source mode" >&2; exit 2 ;; esac

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
OUTPUT_NAME=$(printf '%s' "$REQUESTED_NAME" | sed -E 's/[^A-Za-z0-9._-]+/_/g; s/^[.-]+//; s/[.-]+$//')
[ -n "$OUTPUT_NAME" ] || OUTPUT_NAME=PixelStockGSI
WORK_DIR="$(realpath -m "$WORK_DIR")"
OUTPUT_DIR="$WORK_DIR/output"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
rm -rf -- "$WORK_DIR/pixel-package" "$WORK_DIR/payload-out" "$WORK_DIR/system-root" \
  "$WORK_DIR/system.mount" "$WORK_DIR/repack.mount"
rm -f -- "$OUTPUT_DIR"/*

PACKAGE="$WORK_DIR/google-pixel-package"
SOURCE_IMAGE="$WORK_DIR/source-system.img"
SYSTEM_ROOT="$WORK_DIR/system-root"

bash "$SCRIPT_DIR/download_pixel_stock.sh" "$GOOGLE_URL" "$PACKAGE" "$EXPECTED_SHA256"
bash "$SCRIPT_DIR/extract_pixel_system.sh" "$PACKAGE" "$WORK_DIR" "$SOURCE_IMAGE"
bash "$SCRIPT_DIR/extract_system_root.sh" "$SOURCE_IMAGE" "$WORK_DIR" "$SYSTEM_ROOT"
bash "$SCRIPT_DIR/capture_source_metadata.sh" "$SYSTEM_ROOT" "$WORK_DIR" "$GOOGLE_URL" "$DOWNLOAD_DEVICE_HINT"
bash "$SCRIPT_DIR/patch_pixel_treble.sh" "$SYSTEM_ROOT" "$SOURCE_MODE"
bash "$SCRIPT_DIR/normalize_gsi_layout.sh" "$SYSTEM_ROOT"
bash "$SCRIPT_DIR/build_gsi_image.sh" "$SYSTEM_ROOT" "$OUTPUT_NAME" "$FS_TYPE" "$WORK_DIR" "$OUTPUT_DIR"

BUILD_PROP=$(cat "$WORK_DIR/build-prop.path")
bash "$SCRIPT_DIR/check_gsi_compatibility.sh" \
  "$BUILD_PROP" "$TARGET_MODEL" "$OUTPUT_DIR/compatibility-report.txt" "$EXPECTED_ARCH" "$SYSTEM_ROOT" "$TARGET_PROPERTIES_FILE"

printf '%s\n' "rebuilt-$FS_TYPE" > "$WORK_DIR/image-mode.txt"
printf '%s\n' "$OUTPUT_NAME" > "$WORK_DIR/output-name.txt"
echo "==> [PIPELINE] PixelStockGSI build completed successfully"
