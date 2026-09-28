#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "/tmp/pixelstockgsi-layout.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/system/bin" "$TEST_DIR/system/etc"
touch "$TEST_DIR/system/bin/init"

bash "$ROOT_DIR/scripts/normalize_gsi_layout.sh" "$TEST_DIR" >/dev/null

test -L "$TEST_DIR/init"
test "$(readlink "$TEST_DIR/init")" = "/system/bin/init"
test -L "$TEST_DIR/bin"
test "$(readlink "$TEST_DIR/bin")" = "/system/bin"
test -L "$TEST_DIR/etc"
test "$(readlink "$TEST_DIR/etc")" = "/system/etc"
test -d "$TEST_DIR/vendor"
test -d "$TEST_DIR/metadata"
grep -Fx 'layout_normalization=applied' "$TEST_DIR/pixelstockgsi-layout.properties" >/dev/null
grep -F 'root_symlinks_added=' "$TEST_DIR/pixelstockgsi-layout.properties" >/dev/null

cat > "$TEST_DIR/build.prop" <<'EOF'
ro.treble.enabled=true
ro.product.system.cpu.abilist=arm64-v8a
ro.product.system.cpu.abilist64=arm64-v8a
ro.build.version.sdk=37
ro.build.version.release=17
ro.product.system.device=generic
ro.product.system.model=PixelStockGSI test
ro.llndk.api_level=202604
EOF
bash "$ROOT_DIR/scripts/check_gsi_compatibility.sh" \
  "$TEST_DIR/build.prop" generic "$TEST_DIR/report.txt" arm64 "$TEST_DIR" >/dev/null
grep -Fx 'System layout: system-as-root' "$TEST_DIR/report.txt" >/dev/null
grep -Fx 'GSI layout normalization: applied' "$TEST_DIR/report.txt" >/dev/null

echo "==> Layout normalization tests passed."
