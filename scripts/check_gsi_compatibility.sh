#!/usr/bin/env bash
set -Eeuo pipefail

BUILD_PROP="${1:-}"
TARGET_MODEL="${2:-generic}"
REPORT="${3:-compatibility-report.txt}"
EXPECTED_ARCH="${4:-arm64}"
SYSTEM_ROOT="${5:-}"
if [ -z "$BUILD_PROP" ] || [ ! -f "$BUILD_PROP" ]; then
  echo "[-] build.prop was not found: ${BUILD_PROP:-<empty>}" >&2
  exit 2
fi
case "$EXPECTED_ARCH" in arm64|arm|a64|auto) ;; *) echo "[-] invalid ABI: $EXPECTED_ARCH" >&2; exit 2 ;; esac

prop() {
  awk -v key="$1" '
    /^[[:space:]]*#/ { next }
    index($0, key "=") == 1 { sub(/^[^=]*=/, ""); print; exit }
  ' "$BUILD_PROP"
}

ABI_LIST="$(prop ro.product.system.cpu.abilist || true)"
[ -n "$ABI_LIST" ] || ABI_LIST="$(prop ro.product.cpu.abilist || true)"
ABI64="$(prop ro.product.system.cpu.abilist64 || true)"
[ -n "$ABI64" ] || ABI64="$(prop ro.product.cpu.abilist64 || true)"
ABI="$(prop ro.product.system.cpu.abi || true)"
[ -n "$ABI" ] || ABI="$(prop ro.product.cpu.abi || true)"
TREBLE="$(prop ro.treble.enabled || true)"
SDK="$(prop ro.build.version.sdk || true)"
ANDROID="$(prop ro.build.version.release || true)"
DEVICE="$(prop ro.product.system.device || true)"
MODEL="$(prop ro.product.system.model || true)"
VNDK_VERSION="$(prop ro.vndk.version || true)"
VENDOR_API_LEVEL="$(prop ro.vendor.api_level || true)"
LLNDK_API_LEVEL="$(prop ro.llndk.api_level || true)"
FIRST_API_LEVEL="$(prop ro.product.first_api_level || true)"

SYSTEM_LAYOUT="not-checked"
VINTF_METADATA="not-checked"
LAYOUT_NORMALIZATION="not-checked"
if [ -n "$SYSTEM_ROOT" ] && [ -d "$SYSTEM_ROOT" ]; then
  if { [ -f "$SYSTEM_ROOT/init" ] || { [ -L "$SYSTEM_ROOT/init" ] && [ "$(readlink "$SYSTEM_ROOT/init")" = "/system/bin/init" ]; }; } && [ -d "$SYSTEM_ROOT/system" ]; then
    SYSTEM_LAYOUT="system-as-root"
  elif [ -f "$SYSTEM_ROOT/system/bin/init" ]; then
    SYSTEM_LAYOUT="system-mounted"
  elif [ -f "$SYSTEM_ROOT/bin/init" ]; then
    SYSTEM_LAYOUT="legacy-root"
  else
    SYSTEM_LAYOUT="unknown"
  fi
  if find "$SYSTEM_ROOT" -type f -path '*/etc/vintf/*' -print -quit 2>/dev/null | grep -q .; then
    VINTF_METADATA="present"
  else
    VINTF_METADATA="not-found"
  fi
  if [ -f "$SYSTEM_ROOT/pixelstockgsi-layout.properties" ]; then
    LAYOUT_NORMALIZATION=$(awk -F= '$1 == "layout_normalization" { print $2; exit }' "$SYSTEM_ROOT/pixelstockgsi-layout.properties")
    [ -n "$LAYOUT_NORMALIZATION" ] || LAYOUT_NORMALIZATION="unknown"
  fi
fi

STATUS=PASS
FAILURES=()
WARNINGS=()
warn() { [ "$STATUS" = FAIL ] || STATUS=WARN; WARNINGS+=("$1"); }
fail() { STATUS=FAIL; FAILURES+=("$1"); }

abi_text=",$ABI_LIST,$ABI64,$ABI,"
has64=0
has32=0
case "$abi_text" in *,arm64-v8a,*|*,arm64,*) has64=1 ;; esac
case "$abi_text" in *,armeabi-v7a,*|*,armeabi,*) has32=1 ;; esac
case "$EXPECTED_ARCH" in
  arm64) [ "$has64" = 1 ] || fail "Source system does not advertise ARM64." ;;
  arm|a64) [ "$has32" = 1 ] || fail "Source system does not advertise ARM32." ;;
  auto) [ "$has64" = 1 ] || [ "$has32" = 1 ] || warn "CPU ABI metadata is missing." ;;
esac
case "$TREBLE" in true|1) ;; *) fail "ro.treble.enabled is not true." ;; esac
if [[ "$SDK" =~ ^[0-9]+$ ]] && [ "$SDK" -lt 29 ]; then
  fail "Android SDK $SDK predates the Android 10 Treble baseline."
fi
if [ -z "$VNDK_VERSION" ] && [ -z "$VENDOR_API_LEVEL" ] && [ -z "$LLNDK_API_LEVEL" ]; then
  warn "No VNDK/vendor-API marker is visible in system metadata; target vendor-interface compatibility must be checked separately."
fi
if [[ "$SDK" =~ ^[0-9]+$ ]] && [ "$SDK" -ge 29 ] && [ -n "$SYSTEM_ROOT" ] && [ "$SYSTEM_LAYOUT" != system-as-root ]; then
  warn "Android SDK $SDK image is not detected as system-as-root; verify the target's GSI mount layout before flashing."
fi
if [ "$VINTF_METADATA" = not-found ]; then
  warn "No framework VINTF metadata was found in the extracted system tree."
fi
if [ "$LAYOUT_NORMALIZATION" = applied ]; then
  warn "Generic root mount points/symlinks were added; this does not supply a target ramdisk, kernel, vendor HAL, or device VINTF manifest."
fi
warn "This GSI does not contain a universal kernel, vendor HAL, DTB, boot chain, or vbmeta policy."
warn "Target '$TARGET_MODEL' must provide matching Treble vendor/system_ext/product behavior."

mkdir -p "$(dirname "$REPORT")"
{
  echo "PixelStockGSI compatibility preflight"
  echo "======================================"
  echo "Status: $STATUS"
  echo "Target model: $TARGET_MODEL"
  echo "Requested ABI: $EXPECTED_ARCH"
  echo "Detected ABI: ${ABI_LIST:-${ABI64:-${ABI:-unknown}}}"
  echo "Device marker: ${DEVICE:-unknown}"
  echo "Model marker: ${MODEL:-unknown}"
  echo "Android: ${ANDROID:-unknown} (SDK ${SDK:-unknown})"
  echo "Treble: ${TREBLE:-unknown}"
  echo "VNDK version: ${VNDK_VERSION:-not-present}"
  echo "Vendor API level: ${VENDOR_API_LEVEL:-not-present}"
  echo "LL-NDK API level: ${LLNDK_API_LEVEL:-not-present}"
  echo "First API level: ${FIRST_API_LEVEL:-unknown}"
  echo "System layout: $SYSTEM_LAYOUT"
  echo "GSI layout normalization: $LAYOUT_NORMALIZATION"
  echo "Framework VINTF metadata: $VINTF_METADATA"
  echo
  echo "Hard failures:"
  if [ "${#FAILURES[@]}" -eq 0 ]; then echo "- none"; else printf -- '- %s\n' "${FAILURES[@]}"; fi
  echo
  echo "Warnings:"
  if [ "${#WARNINGS[@]}" -eq 0 ]; then echo "- none"; else printf -- '- %s\n' "${WARNINGS[@]}"; fi
} | tee "$REPORT"

[ "$STATUS" != FAIL ] || exit 1
