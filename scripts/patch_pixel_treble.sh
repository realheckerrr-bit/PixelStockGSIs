#!/usr/bin/env bash
set -Eeuo pipefail

SYSTEM_ROOT="${1:-}"
SOURCE_MODE="${2:-pixel_stock}"
if [ -z "$SYSTEM_ROOT" ] || [ ! -d "$SYSTEM_ROOT" ]; then
  echo "usage: $0 <extracted-system-root> [pixel_stock|official_gsi]" >&2
  exit 2
fi
case "$SOURCE_MODE" in pixel_stock|official_gsi) ;; *) echo "[-] invalid source mode" >&2; exit 2 ;; esac

if [ "$(id -u)" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
  SUDO=()
else
  SUDO=(sudo)
fi

BUILD_PROP=""
for candidate in \
  "$SYSTEM_ROOT/system/etc/build.prop" \
  "$SYSTEM_ROOT/system/build.prop" \
  "$SYSTEM_ROOT/etc/build.prop" \
  "$SYSTEM_ROOT/build.prop"; do
  if [ -f "$candidate" ]; then
    BUILD_PROP="$candidate"
    break
  fi
done
if [ -z "$BUILD_PROP" ]; then
  BUILD_PROP=$("${SUDO[@]}" find "$SYSTEM_ROOT" \
    -path '*/system_dlkm' -prune -o \
    -path '*/vendor' -prune -o \
    -path '*/product' -prune -o \
    -path '*/system_ext' -prune -o \
    -type f -name build.prop -print -quit)
fi
if [ -z "$BUILD_PROP" ]; then
  echo "[-] Pixel system tree has no build.prop." >&2
  exit 1
fi

set_prop() {
  local key="$1"
  local value="$2"
  local escaped_key escaped_value
  escaped_key="${key//./\\.}"
  escaped_value=$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')
  if grep -Eq "^${escaped_key}=" "$BUILD_PROP"; then
    "${SUDO[@]}" sed -i -E "s|^${escaped_key}=.*|${key}=${escaped_value}|" "$BUILD_PROP"
  else
    printf '%s=%s\n' "$key" "$value" | "${SUDO[@]}" tee -a "$BUILD_PROP" >/dev/null
  fi
}

echo "==> [PATCH] Patching Pixel system metadata for Project Treble/GSI"
"${SUDO[@]}" chmod 644 "$BUILD_PROP"
set_prop ro.treble.enabled true
set_prop ro.apex.updatable false
# Keep source identity in source-system-properties.txt, but make the rebuilt
# system partition expose a generic product identity like a GSI. These are
# framework-facing markers; vendor, kernel, DTB, and boot metadata are not
# copied or fabricated here.
set_prop ro.product.device generic
set_prop ro.product.name PixelStockGSI
set_prop ro.product.model PixelStockGSI
set_prop ro.product.manufacturer PixelStockGSI
set_prop ro.build.product generic
set_prop ro.product.system.device generic
set_prop ro.product.system.name PixelStockGSI
set_prop ro.product.system.model PixelStockGSI
set_prop ro.gsi.type PixelStockGSI
set_prop ro.gsi.official false

original_id=$(grep -m1 '^ro.build.display.id=' "$BUILD_PROP" | cut -d= -f2- || true)
[ -n "$original_id" ] || original_id="PixelStockGSI"
case "$original_id" in
  *PixelStockGSI*) branded_id="$original_id" ;;
  *) branded_id="$original_id via PixelStockGSI's" ;;
esac
set_prop ro.build.display.id "$branded_id"

original_desc=$(grep -m1 '^ro.build.description=' "$BUILD_PROP" | cut -d= -f2- || true)
if [ -n "$original_desc" ] && [[ "$original_desc" != *PixelStockGSI* ]]; then
  set_prop ro.build.description "$original_desc via PixelStockGSI's"
fi

# This marker is additive and does not pretend that a Pixel kernel or vendor
# HAL is universal. It is useful for bug reports and recovery diagnostics.
MARKER_PATH="$SYSTEM_ROOT/pixelstockgsi.properties"
"${SUDO[@]}" tee "$MARKER_PATH" >/dev/null <<EOF
tool=PixelStockGSI's
release_type=unofficial
treble_patch=true
source_mode=$SOURCE_MODE
source_build_prop=$(basename "$BUILD_PROP")
EOF
"${SUDO[@]}" chmod 644 "$MARKER_PATH"

printf '%s\n' "$BUILD_PROP" > "$(dirname "$SYSTEM_ROOT")/build-prop.path"
echo "==> [PATCH] Treble properties written to $BUILD_PROP"
