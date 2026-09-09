#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/folio-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
products="$build_dir/Build/Products/Debug"
for app in Write Research; do
    test -x "$products/$app.app/Contents/MacOS/$app"
    test -d "$products/$app.app/Contents/Frameworks/${app}Kit.framework"
done
for library in FKModelFoundations FKPackageSupport FKXMLSupport; do
    test -f "$products/FolioKit.framework/Frameworks/lib${library}.dylib"
done
for library in FWManuscript FWEditor; do
    test -f "$products/Write.app/Contents/Frameworks/WriteKit.framework/Frameworks/lib${library}.dylib"
done
echo 'Suite build and development embedding checks passed.'
