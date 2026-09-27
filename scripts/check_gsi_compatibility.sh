#!/usr/bin/env bash
set -Eeuo pipefail

BUILD_PROP="${1:-}"
TARGET_MODEL="${2:-generic}"
REPORT="${3:-compatibility-report.txt}"
EXPECTED_ARCH="${4:-arm64}"
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
  echo
  echo "Hard failures:"
  if [ "${#FAILURES[@]}" -eq 0 ]; then echo "- none"; else printf -- '- %s\n' "${FAILURES[@]}"; fi
  echo
  echo "Warnings:"
  if [ "${#WARNINGS[@]}" -eq 0 ]; then echo "- none"; else printf -- '- %s\n' "${WARNINGS[@]}"; fi
} | tee "$REPORT"

[ "$STATUS" != FAIL ] || exit 1
