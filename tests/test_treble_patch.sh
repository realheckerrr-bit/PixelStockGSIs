#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pixelstockgsi-patch.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/system/etc" "$TEST_DIR/system/system_dlkm/etc"
cat > "$TEST_DIR/system/etc/build.prop" <<'EOF'
ro.build.display.id=AP3A.test.release
ro.build.description=oriole-user 16 AP3A release-keys
ro.product.device=oriole
ro.product.name=oriole
ro.product.model=Pixel 6
ro.product.manufacturer=Google
ro.build.product=oriole
ro.product.system.device=oriole
ro.product.system.name=oriole
ro.product.system.model=Pixel 6
ro.product.system.cpu.abilist=arm64-v8a,armeabi-v7a
ro.build.version.sdk=36
EOF
cat > "$TEST_DIR/system/system_dlkm/etc/build.prop" <<'EOF'
ro.build.display.id=system-dlkm-build
EOF

bash "$ROOT_DIR/scripts/patch_pixel_treble.sh" "$TEST_DIR/system" >/dev/null

grep -Fx 'ro.treble.enabled=true' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.apex.updatable=false' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.device=generic' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.name=PixelStockGSI' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.model=PixelStockGSI' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.manufacturer=PixelStockGSI' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.build.product=generic' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.system.device=generic' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.system.name=PixelStockGSI' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.system.model=PixelStockGSI' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -F "via PixelStockGSI's" "$TEST_DIR/system/etc/build.prop" >/dev/null
if grep -q 'ro.treble.enabled' "$TEST_DIR/system/system_dlkm/etc/build.prop"; then
  echo "[-] Nested system_dlkm metadata was patched as the system build.prop." >&2
  exit 1
fi
grep -Fx "tool=PixelStockGSI's" "$TEST_DIR/system/pixelstockgsi.properties" >/dev/null
grep -Fx 'source_mode=pixel_stock' "$TEST_DIR/system/pixelstockgsi.properties" >/dev/null

OFFICIAL_TEST_DIR="$TEST_DIR/official-gsi"
mkdir -p "$OFFICIAL_TEST_DIR/system/etc"
cp "$TEST_DIR/system/etc/build.prop" "$OFFICIAL_TEST_DIR/system/etc/build.prop"
bash "$ROOT_DIR/scripts/patch_pixel_treble.sh" "$OFFICIAL_TEST_DIR/system" official_gsi >/dev/null
grep -Fx 'source_mode=official_gsi' "$OFFICIAL_TEST_DIR/system/pixelstockgsi.properties" >/dev/null

echo "==> Treble patch tests passed."
