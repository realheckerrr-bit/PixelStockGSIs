#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pixelstockgsi-source-meta.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/system/etc"
cat > "$TEST_DIR/system/etc/build.prop" <<'EOF'
ro.product.device=oriole
ro.product.system.device=oriole
ro.product.model=Pixel 6
ro.product.system.model=Pixel 6
ro.product.name=oriole
ro.build.id=AP3A.test
ro.build.display.id=AP3A.test.release
ro.build.version.release=16
ro.build.version.sdk=36
ro.build.version.security_patch=2026-09-05
ro.build.fingerprint=google/oriole/oriole:16/AP3A.test/1234567:user/release-keys
ro.treble.enabled=true
ro.product.system.cpu.abilist=arm64-v8a,armeabi-v7a
ro.product.system.cpu.abilist64=arm64-v8a
EOF

bash "$ROOT_DIR/scripts/capture_source_metadata.sh" \
  "$TEST_DIR/system" \
  "$TEST_DIR/work" \
  "https://dl.google.com/dl/android/aosp/oriole-test.zip" \
  "oriole" >/dev/null

grep -Fx 'Download package: oriole-test.zip' "$TEST_DIR/work/source-provenance.txt" >/dev/null
grep -Fx 'Download device hint: oriole' "$TEST_DIR/work/source-provenance.txt" >/dev/null
grep -Fx 'ro.product.device=oriole' "$TEST_DIR/work/source-provenance.txt" >/dev/null
grep -Fx 'ro.build.fingerprint=google/oriole/oriole:16/AP3A.test/1234567:user/release-keys' "$TEST_DIR/work/source-system-properties.txt" >/dev/null
grep -Fx 'ro.product.system.device=oriole' "$TEST_DIR/work/source-system-properties.txt" >/dev/null

echo "==> Source metadata tests passed."
