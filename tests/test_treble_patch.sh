#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pixelstockgsi-patch.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/system/etc" "$TEST_DIR/system/system_dlkm/etc"
cat > "$TEST_DIR/system/etc/build.prop" <<'EOF'
ro.build.display.id=AP3A.test.release
ro.build.description=oriole-user 16 AP3A release-keys
ro.product.system.cpu.abilist=arm64-v8a,armeabi-v7a
ro.build.version.sdk=36
EOF
cat > "$TEST_DIR/system/system_dlkm/etc/build.prop" <<'EOF'
ro.build.display.id=system-dlkm-build
EOF

bash "$ROOT_DIR/scripts/patch_pixel_treble.sh" "$TEST_DIR/system" >/dev/null

grep -Fx 'ro.treble.enabled=true' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.apex.updatable=false' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -Fx 'ro.product.system.device=generic' "$TEST_DIR/system/etc/build.prop" >/dev/null
grep -F "via PixelStockGSI's" "$TEST_DIR/system/etc/build.prop" >/dev/null
if grep -q 'ro.treble.enabled' "$TEST_DIR/system/system_dlkm/etc/build.prop"; then
  echo "[-] Nested system_dlkm metadata was patched as the system build.prop." >&2
  exit 1
fi
grep -Fx "tool=PixelStockGSI's" "$TEST_DIR/system/pixelstockgsi.properties" >/dev/null

echo "==> Treble patch tests passed."
