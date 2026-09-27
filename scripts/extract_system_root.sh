#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-}"
WORK_DIR="${2:-}"
SYSTEM_ROOT="${3:-}"
if [ -z "$IMAGE" ] || [ -z "$WORK_DIR" ] || [ -z "$SYSTEM_ROOT" ] || [ ! -f "$IMAGE" ]; then
  echo "usage: $0 <system-img> <work-dir> <system-root>" >&2
  exit 2
fi

RAW_IMAGE="$WORK_DIR/system.raw.img"
MOUNT_DIR="$WORK_DIR/system.mount"
rm -rf -- "$SYSTEM_ROOT" "$MOUNT_DIR"
mkdir -p "$SYSTEM_ROOT" "$MOUNT_DIR"

MAGIC=$(od -An -tx1 -N4 "$IMAGE" | tr -d '[:space:]')
if [ "$MAGIC" = "3aff26ed" ]; then
  echo "==> [EXTRACT] Converting Android sparse system image"
  simg2img "$IMAGE" "$RAW_IMAGE"
else
  cp -- "$IMAGE" "$RAW_IMAGE"
fi

FS_TYPE=$(blkid -o value -s TYPE "$RAW_IMAGE" 2>/dev/null || true)
case "$FS_TYPE" in
  ext4|ext3|ext2)
    echo "==> [EXTRACT] Reading $FS_TYPE filesystem"
    cleanup() {
      if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        sudo umount "$MOUNT_DIR"
      fi
    }
    trap cleanup EXIT
    sudo mount -o loop,ro "$RAW_IMAGE" "$MOUNT_DIR"
    sudo cp -a "$MOUNT_DIR"/. "$SYSTEM_ROOT"/
    cleanup
    trap - EXIT
    ;;
  erofs)
    echo "==> [EXTRACT] Reading EROFS filesystem"
    fsck.erofs --extract="$SYSTEM_ROOT" "$RAW_IMAGE"
    ;;
  *)
    echo "[-] Unsupported system filesystem: ${FS_TYPE:-unknown}" >&2
    file -b "$IMAGE" >&2 || true
    exit 1
    ;;
esac

find "$SYSTEM_ROOT" -type f -name build.prop -exec sudo chmod 644 {} + 2>/dev/null || true
printf '%s\n' "$FS_TYPE" > "$WORK_DIR/source-filesystem.txt"
echo "==> [EXTRACT] System tree ready: $SYSTEM_ROOT"
