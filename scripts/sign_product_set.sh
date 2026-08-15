#!/usr/bin/env bash
# Adhoc-sign product_set for ICH ramdisk trustcache (CDHash must match signed binary).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/product_set}"
ENT="${ROOT}/entitlements/product_set.plist"

if [ ! -f "$BIN" ]; then
  echo "ERROR: missing $BIN" >&2
  exit 1
fi

if [ ! -f "$ENT" ]; then
  echo "ERROR: missing $ENT" >&2
  exit 1
fi

codesign -s - --force --timestamp=none --entitlements "$ENT" "$BIN"
codesign --verify --verbose=4 "$BIN"

echo ""
echo "=== CDHash (add THIS to trustcache.img4 after signing) ==="
codesign -dv --verbose=4 "$BIN" 2>&1 | grep -E 'CDHash|TeamIdentifier|Identifier' || true

CDHASH="$(codesign -dv --verbose=4 "$BIN" 2>&1 | awk -F= '/CDHash/ {print $2; exit}' | tr -d ' ')"
if [ -n "$CDHASH" ]; then
  echo "$CDHASH" > "${BIN}.cdhash.txt"
  echo "wrote ${BIN}.cdhash.txt"
fi

shasum -a 256 "$BIN"
