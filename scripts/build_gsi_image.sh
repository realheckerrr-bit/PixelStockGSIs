#!/usr/bin/env bash
set -Eeuo pipefail

SYSTEM_ROOT="${1:-}"
OUTPUT_NAME="${2:-PixelStockGSI}"
FS_TYPE="${3:-ext4}"
WORK_DIR="${4:-}"
OUTPUT_DIR="${5:-}"

if [ -z "$SYSTEM_ROOT" ] || [ ! -d "$SYSTEM_ROOT" ] || [ -z "$WORK_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "usage: $0 <system-root> <output-name> <ext4|erofs> <work-dir> <output-dir>" >&2
  exit 2
fi
case "$FS_TYPE" in ext4|erofs) ;; *) echo "[-] filesystem must be ext4 or erofs" >&2; exit 2 ;; esac

if [ "$(id -u)" -eq 0 ] || ! command -v sudo >/dev/null 2>&1; then
  SUDO=()
else
  SUDO=(sudo)
fi

OUTPUT_NAME=$(printf '%s' "$OUTPUT_NAME" | sed -E 's/[^A-Za-z0-9._-]+/_/g; s/^[.-]+//; s/[.-]+$//')
[ -n "$OUTPUT_NAME" ] || OUTPUT_NAME=PixelStockGSI
mkdir -p "$OUTPUT_DIR"
rm -f -- "$OUTPUT_DIR"/*.img "$OUTPUT_DIR"/*.img.xz "$OUTPUT_DIR"/*.img.gz

RAW_IMAGE="$WORK_DIR/rebuilt.raw.img"
IMAGE="$OUTPUT_DIR/${OUTPUT_NAME}.img"
DSU_RAW="$WORK_DIR/${OUTPUT_NAME}.dsu.raw.img"

if [ "$FS_TYPE" = "erofs" ]; then
  echo "==> [BUILD] Creating EROFS GSI"
  "${SUDO[@]}" mkfs.erofs -z lz4hc "$IMAGE" "$SYSTEM_ROOT" \
    || { rm -f -- "$IMAGE"; "${SUDO[@]}" mkfs.erofs -z lz4 "$IMAGE" "$SYSTEM_ROOT"; }
else
  DIR_SIZE=$(sudo du -sb "$SYSTEM_ROOT" | cut -f1)
  BUFFER=$((128 * 1024 * 1024))
  TOTAL=$((DIR_SIZE + BUFFER))
  TOTAL=$(( ((TOTAL + 4095) / 4096) * 4096 ))
  echo "==> [BUILD] Creating ext4 GSI (${TOTAL} bytes before shrink)"
  truncate -s "$TOTAL" "$RAW_IMAGE"
  mke2fs -t ext4 -b 4096 -F -O ^has_journal -O ^dir_index -L system "$RAW_IMAGE" >/dev/null
  if command -v e2fsdroid >/dev/null 2>&1; then
    E2FSDROID_ARGS=(-e -f "$SYSTEM_ROOT" -a /system)
    FILE_CONTEXTS=$("${SUDO[@]}" find "$SYSTEM_ROOT" -type f \( \
      -name file_contexts -o -name plat_file_contexts -o -name vendor_file_contexts \
    \) -print -quit 2>/dev/null || true)
    if [ -n "$FILE_CONTEXTS" ]; then
      E2FSDROID_ARGS+=(-S "$FILE_CONTEXTS")
    fi
    "${SUDO[@]}" e2fsdroid "${E2FSDROID_ARGS[@]}" "$RAW_IMAGE"
  else
    MOUNT_DIR="$WORK_DIR/repack.mount"
    mkdir -p "$MOUNT_DIR"
    sudo mount -o loop "$RAW_IMAGE" "$MOUNT_DIR"
    sudo cp -a "$SYSTEM_ROOT"/. "$MOUNT_DIR"/
    sudo umount "$MOUNT_DIR"
  fi
  e2fsck_status=0
  e2fsck -fy "$RAW_IMAGE" >/dev/null || e2fsck_status=$?
  if [ "$e2fsck_status" -gt 1 ]; then
    echo "[-] ext4 verification failed with status $e2fsck_status" >&2
    exit 1
  fi
  resize2fs -M "$RAW_IMAGE" >/dev/null
  if command -v img2simg >/dev/null 2>&1; then
    img2simg "$RAW_IMAGE" "$IMAGE"
  else
    cp -- "$RAW_IMAGE" "$IMAGE"
  fi
fi

magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d '[:space:]')
if [ "$magic" = "3aff26ed" ]; then
  simg2img "$IMAGE" "$DSU_RAW"
  gzip -9 -c "$DSU_RAW" > "$OUTPUT_DIR/${OUTPUT_NAME}.img.gz"
else
  gzip -9 -c "$IMAGE" > "$OUTPUT_DIR/${OUTPUT_NAME}.img.gz"
fi
xz -9 -T0 -f "$IMAGE"

test -s "$OUTPUT_DIR/${OUTPUT_NAME}.img.xz"
test -s "$OUTPUT_DIR/${OUTPUT_NAME}.img.gz"
echo "==> [BUILD] Published image assets in $OUTPUT_DIR"
