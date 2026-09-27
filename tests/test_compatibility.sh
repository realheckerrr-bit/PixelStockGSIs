#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pixelstockgsi-compat.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

cat > "$TEST_DIR/build.prop" <<'EOF'
ro.treble.enabled=true
ro.product.system.cpu.abilist=arm64-v8a,armeabi-v7a
ro.product.system.cpu.abilist64=arm64-v8a
ro.build.version.sdk=36
ro.build.version.release=16
ro.product.system.device=generic
ro.product.system.model=PixelStockGSI test
EOF

bash "$ROOT_DIR/scripts/check_gsi_compatibility.sh" \
  "$TEST_DIR/build.prop" generic "$TEST_DIR/report.txt" arm64 >/dev/null
grep -Fx 'Status: WARN' "$TEST_DIR/report.txt" >/dev/null
grep -F 'universal kernel' "$TEST_DIR/report.txt" >/dev/null

echo "==> Compatibility tests passed."
