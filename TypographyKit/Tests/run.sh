#!/bin/sh
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
set -eu
BUILD_PRODUCTS=${1:?pass Xcode Build/Products/Debug directory}
ARCHITECTURE=$(uname -m)
mkdir -p "$BUILD_PRODUCTS/ModuleCache"
swiftc -parse-as-library -swift-version 6 -target "$ARCHITECTURE-apple-macos14.0" \
  -module-cache-path "$BUILD_PRODUCTS/ModuleCache" -F "$BUILD_PRODUCTS" -framework TypographyKit \
  "$(dirname "$0")/CompositionBehavior.swift" -o "$BUILD_PRODUCTS/TypographyKitBehavior"
DYLD_FRAMEWORK_PATH="$BUILD_PRODUCTS" "$BUILD_PRODUCTS/TypographyKitBehavior"
