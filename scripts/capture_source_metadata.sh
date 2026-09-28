#!/usr/bin/env bash
set -Eeuo pipefail

SYSTEM_ROOT="${1:-}"
WORK_DIR="${2:-}"
DOWNLOAD_URL="${3:-}"
DOWNLOAD_DEVICE_HINT="${4:-}"

if [ -z "$SYSTEM_ROOT" ] || [ ! -d "$SYSTEM_ROOT" ] || [ -z "$WORK_DIR" ] || [ -z "$DOWNLOAD_URL" ]; then
  echo "usage: $0 <extracted-system-root> <work-dir> <download-url> [download-device-hint]" >&2
  exit 2
fi

BUILD_PROP=""
for candidate in \
  "$SYSTEM_ROOT/system/etc/build.prop" \
  "$SYSTEM_ROOT/system/build.prop" \
  "$SYSTEM_ROOT/etc/build.prop" \
  "$SYSTEM_ROOT/build.prop"; do
  if [ -f "$candidate" ]; then
    BUILD_PROP="$candidate"
    break
  fi
done
if [ -z "$BUILD_PROP" ]; then
  BUILD_PROP=$(find "$SYSTEM_ROOT" \
    -path '*/system_dlkm' -prune -o \
    -path '*/vendor' -prune -o \
    -path '*/product' -prune -o \
    -path '*/system_ext' -prune -o \
    -type f -name build.prop -print -quit)
fi
if [ -z "$BUILD_PROP" ]; then
  echo "[-] Cannot capture source metadata: no build.prop was found." >&2
  exit 1
fi

prop() {
  awk -v key="$1" '
    /^[[:space:]]*#/ { next }
    index($0, key "=") == 1 { sub(/^[^=]*=/, ""); print; exit }
  ' "$BUILD_PROP"
}

url_without_query="${DOWNLOAD_URL%%\?*}"
package_name="${url_without_query##*/}"
[ -n "$package_name" ] || package_name="unknown"

if [ -z "$DOWNLOAD_DEVICE_HINT" ] || [ "$DOWNLOAD_DEVICE_HINT" = "auto" ]; then
  package_stem="${package_name%.zip}"
  case "$package_stem" in
    aosp_*|gsi_*|generic_*|*-gsi-*|*_gsi_*)
      DOWNLOAD_DEVICE_HINT="not-device-specific (official GSI package)"
      ;;
    *)
      package_candidate="${package_stem%%[-_]*}"
      if [[ "$package_candidate" =~ ^[a-z0-9][a-z0-9]*$ ]] &&
         [[ "$package_candidate" != "unknown" ]] &&
         [[ "$package_candidate" != "google" ]]; then
        DOWNLOAD_DEVICE_HINT="$package_candidate (derived from package filename)"
      else
        DOWNLOAD_DEVICE_HINT="not-supplied"
      fi
      ;;
  esac
fi

metadata="$WORK_DIR/source-provenance.txt"
properties="$WORK_DIR/source-system-properties.txt"
mkdir -p "$WORK_DIR"

{
  echo "Downloaded source provenance"
  echo "==========================="
  echo "Download URL: $DOWNLOAD_URL"
  echo "Download package: $package_name"
  echo "Download device hint: ${DOWNLOAD_DEVICE_HINT:-not-supplied}"
  echo "Original build.prop: ${BUILD_PROP#"$SYSTEM_ROOT"/}"
  echo
  echo "Original system properties"
  echo "--------------------------"
  for key in \
    ro.product.device \
    ro.product.system.device \
    ro.product.vendor.device \
    ro.product.odm.device \
    ro.build.product \
    ro.product.name \
    ro.product.system.name \
    ro.product.model \
    ro.product.system.model \
    ro.product.manufacturer \
    ro.build.id \
    ro.build.display.id \
    ro.build.version.release \
    ro.build.version.sdk \
    ro.build.version.incremental \
    ro.build.version.security_patch \
    ro.build.version.codename \
    ro.build.fingerprint \
    ro.build.description \
    ro.bootimage.build.fingerprint \
    ro.treble.enabled \
    ro.vndk.version \
    ro.vendor.api_level \
    ro.llndk.api_level \
    ro.product.first_api_level \
    ro.product.cpu.abilist \
    ro.product.system.cpu.abilist \
    ro.product.cpu.abilist64 \
    ro.product.system.cpu.abilist64; do
    value=$(prop "$key" || true)
    echo "$key=${value:-not-present}"
  done
} > "$metadata"

# Keep a compact machine-readable copy for the workflow. It is consumed into
# release-notes.md; it is deliberately not published as a separate build.txt.
awk '/^Original system properties$/{capture=1; next} capture && /^--------------------------$/{next} capture && NF{print}' "$metadata" > "$properties"

printf '%s\n' "$metadata" > "$WORK_DIR/source-provenance.path"
printf '%s\n' "$properties" > "$WORK_DIR/source-system-properties.path"
printf '%s\n' "$BUILD_PROP" > "$WORK_DIR/source-build-prop.path"
echo "==> [METADATA] Captured source properties from ${BUILD_PROP#"$SYSTEM_ROOT"/}"
echo "    Download device hint: ${DOWNLOAD_DEVICE_HINT:-not-supplied}"
echo "    Download package: $package_name"
