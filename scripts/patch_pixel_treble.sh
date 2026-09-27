#!/usr/bin/env bash
set -Eeuo pipefail

SYSTEM_ROOT="${1:-}"
if [ -z "$SYSTEM_ROOT" ] || [ ! -d "$SYSTEM_ROOT" ]; then
  echo "usage: $0 <extracted-system-root>" >&2
  exit 2
fi

if [ "$(id -u)" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
  SUDO=()
else
  SUDO=(sudo)
fi

BUILD_PROP=$("${SUDO[@]}" find "$SYSTEM_ROOT" -maxdepth 4 -type f -name build.prop -print -quit)
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
set_prop ro.product.system.device generic
set_prop ro.product.system.name PixelStockGSI
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
source_build_prop=$(basename "$BUILD_PROP")
EOF
"${SUDO[@]}" chmod 644 "$MARKER_PATH"

printf '%s\n' "$BUILD_PROP" > "$(dirname "$SYSTEM_ROOT")/build-prop.path"
echo "==> [PATCH] Treble properties written to $BUILD_PROP"
