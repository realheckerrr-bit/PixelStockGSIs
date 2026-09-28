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

added_mountpoints=()
added_symlinks=()

add_mountpoint() {
  local path="$1"
  if [ ! -e "$SYSTEM_ROOT/$path" ] && [ ! -L "$SYSTEM_ROOT/$path" ]; then
    "${SUDO[@]}" mkdir -p "$SYSTEM_ROOT/$path"
    added_mountpoints+=("$path")
  fi
}

add_absolute_symlink() {
  local name="$1"
  local target="$2"
  local parent
  parent="$(dirname "$SYSTEM_ROOT/$name")"
  "${SUDO[@]}" mkdir -p "$parent"
  if [ ! -e "$SYSTEM_ROOT/$name" ] && [ ! -L "$SYSTEM_ROOT/$name" ]; then
    "${SUDO[@]}" ln -s "$target" "$SYSTEM_ROOT/$name"
    added_symlinks+=("$name->$target")
  fi
}

for path in apex bootstrap-apex config data data_mirror debug_ramdisk dev linkerconfig metadata mnt odm odm_dlkm oem postinstall proc second_stage_resources storage sys system system_dlkm tmp vendor vendor_dlkm; do
  add_mountpoint "$path"
done

if [ -f "$SYSTEM_ROOT/system/bin/init" ]; then
  add_absolute_symlink init /system/bin/init
  add_absolute_symlink etc /system/etc
  add_absolute_symlink bin /system/bin
  if [ ! -e "$SYSTEM_ROOT/system/vendor" ] && [ ! -L "$SYSTEM_ROOT/system/vendor" ]; then
    add_absolute_symlink system/vendor /vendor
  fi
fi

normalization="$SYSTEM_ROOT/pixelstockgsi-layout.properties"
{
  echo "layout_normalization=applied"
  if [ "${#added_mountpoints[@]}" -gt 0 ]; then
    printf 'root_mountpoints_added=%s\n' "$(IFS=,; echo "${added_mountpoints[*]}")"
  else
    echo "root_mountpoints_added=none"
  fi
  if [ "${#added_symlinks[@]}" -gt 0 ]; then
    printf 'root_symlinks_added=%s\n' "$(IFS=,; echo "${added_symlinks[*]}")"
  else
    echo "root_symlinks_added=none"
  fi
} | "${SUDO[@]}" tee "$normalization" >/dev/null
"${SUDO[@]}" chmod 644 "$normalization"

echo "==> [LAYOUT] Generic GSI root layout normalized"
echo "    Root mount points added: ${#added_mountpoints[@]}"
echo "    Root symlinks added: ${#added_symlinks[@]}"
