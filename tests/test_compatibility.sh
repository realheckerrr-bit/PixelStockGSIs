#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pixelstockgsi-compat.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/system-root/system/bin" "$TEST_DIR/system-root/system/etc/vintf"
touch "$TEST_DIR/system-root/init" "$TEST_DIR/system-root/system/bin/init"
touch "$TEST_DIR/system-root/system/etc/vintf/manifest.xml"

cat > "$TEST_DIR/build.prop" <<'EOF'
ro.treble.enabled=true
ro.product.system.cpu.abilist=arm64-v8a,armeabi-v7a
ro.product.system.cpu.abilist64=arm64-v8a
ro.build.version.sdk=36
ro.build.version.release=16
ro.product.system.device=generic
ro.product.system.model=PixelStockGSI test
ro.vndk.version=36
ro.llndk.api_level=36
ro.product.first_api_level=35
EOF

bash "$ROOT_DIR/scripts/check_gsi_compatibility.sh" \
  "$TEST_DIR/build.prop" generic "$TEST_DIR/report.txt" arm64 "$TEST_DIR/system-root" >/dev/null
grep -Fx 'Status: WARN' "$TEST_DIR/report.txt" >/dev/null
grep -F 'universal kernel' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'VNDK version: 36' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'LL-NDK API level: 36' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'System layout: system-as-root' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'GSI layout normalization: not-checked' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'Framework VINTF metadata: present' "$TEST_DIR/report.txt" >/dev/null

echo "==> Compatibility tests passed."
