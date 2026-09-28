#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
TEST_DIR=$(mktemp -d "/tmp/pixelstockgsi-package.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT

truncate -s 16M "$TEST_DIR/fixture-system.img"
mke2fs -t ext4 -b 4096 -F "$TEST_DIR/fixture-system.img" >/dev/null
printf 'payload fixture\n' > "$TEST_DIR/payload.bin"
(cd "$TEST_DIR" && zip -q ota-fixture.zip payload.bin)

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/payload-dumper-go" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
test -n "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp "$FIXTURE_SYSTEM_IMAGE" "$OUTPUT_DIR/system.img"
EOF
chmod +x "$TEST_DIR/bin/payload-dumper-go"

PATH="$TEST_DIR/bin:$PATH" \
  FIXTURE_SYSTEM_IMAGE="$TEST_DIR/fixture-system.img" \
  bash "$ROOT_DIR/scripts/extract_pixel_system.sh" \
    "$TEST_DIR/ota-fixture.zip" \
    "$TEST_DIR/work" \
    "$TEST_DIR/work/source-system.img" >/dev/null

test -s "$TEST_DIR/work/source-system.img"
test "$(sha256sum "$TEST_DIR/fixture-system.img" | cut -d' ' -f1)" = "$(sha256sum "$TEST_DIR/work/source-system.img" | cut -d' ' -f1)"
grep -Fqi 'filesystem' "$TEST_DIR/work/source-system-type.txt"
grep -Fq '/payload-out/system.img' "$TEST_DIR/work/source-system-path.txt"

echo "==> Package extraction tests passed."
