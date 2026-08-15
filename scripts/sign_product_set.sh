#!/usr/bin/env bash
# Adhoc-sign product_set for ICH ramdisk trustcache.
# Use bare adhoc (no entitlements) — platform-application triggers AMFI kill even with trustcache.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/product_set}"

if [ ! -f "$BIN" ]; then
  echo "ERROR: missing $BIN" >&2
  exit 1
fi

# Same as manual lab sign; do NOT pass platform-application entitlements here.
codesign -s - --force --timestamp=none "$BIN"
codesign --verify --verbose=4 "$BIN"

echo ""
echo "=== CDHash (add THIS to trustcache.img4 after signing) ==="
codesign -dv --verbose=4 "$BIN" 2>&1 | grep -E 'CDHash|TeamIdentifier|Identifier|flags' || true

CDHASH="$(codesign -dv --verbose=4 "$BIN" 2>&1 | awk -F= '/CDHash/ {print $2; exit}' | tr -d ' ')"
if [ -n "$CDHASH" ]; then
  echo "CDHash=${CDHASH}" > "${BIN}.cdhash.txt"
  echo "wrote ${BIN}.cdhash.txt"
fi

shasum -a 256 "$BIN"
