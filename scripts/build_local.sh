#!/usr/bin/env bash
# Local Mac build: gestaltpatcher and/or libiokit_spoof.dylib
set -euo pipefail
IOS_MIN="${1:-15.0}"
TARGET="${2:-both}"
MACH_ARCH="${3:-arm64e}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

echo "SDK=$SDK IOS_MIN=$IOS_MIN TARGET=$TARGET MACH_ARCH=$MACH_ARCH"

if [[ "$TARGET" == "gestaltpatcher" || "$TARGET" == "both" ]]; then
  xcrun clang \
    -target "${MACH_ARCH}-apple-ios${IOS_MIN}" \
    -arch "${MACH_ARCH}" \
    -isysroot "$SDK" \
    -mios-version-min="${IOS_MIN}" \
    -fobjc-arc \
    -framework Foundation \
    -o gestaltpatcher \
    poc.m
  file gestaltpatcher
fi

if [[ "$TARGET" == "iokit_spoof" || "$TARGET" == "both" ]]; then
  # Always arm64e for mobileactivationd injection
  xcrun clang \
    -target "arm64e-apple-ios${IOS_MIN}" \
    -arch arm64e \
    -isysroot "$SDK" \
    -mios-version-min="${IOS_MIN}" \
    -dynamiclib \
    -fobjc-arc \
    -O2 \
    -install_name "@rpath/libiokit_spoof.dylib" \
    -framework Foundation \
    -framework IOKit \
    -framework CoreFoundation \
    -ldl \
    -o libiokit_spoof.dylib \
    iokit_spoof.m
  file libiokit_spoof.dylib
fi

if [[ "$TARGET" == "product_set" || "$TARGET" == "all" || "$TARGET" == "both" ]]; then
  xcrun clang \
    -target "arm64e-apple-ios${IOS_MIN}" \
    -arch arm64e \
    -isysroot "$SDK" \
    -mios-version-min="${IOS_MIN}" \
    -fobjc-arc \
    -O2 \
    -framework Foundation \
    -framework IOKit \
    -framework CoreFoundation \
    -ldl \
    -o product_set \
    product_set.m
  file product_set
fi

if [[ "$TARGET" == "product_set" || "$TARGET" == "all" || "$TARGET" == "both" ]]; then
  chmod +x scripts/sign_product_set.sh
  ./scripts/sign_product_set.sh product_set
fi

echo "Done."
