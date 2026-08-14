#!/usr/bin/env bash
# Build on a Mac with Xcode installed.
set -euo pipefail
IOS_MIN="${1:-15.0}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "SDK=$SDK IOS_MIN=$IOS_MIN"
xcrun clang \
  -target "arm64-apple-ios${IOS_MIN}" \
  -isysroot "$SDK" \
  -mios-version-min="${IOS_MIN}" \
  -fobjc-arc \
  -framework Foundation \
  -o gestaltpatcher \
  poc.m
file gestaltpatcher
shasum -a 256 gestaltpatcher
