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
for app in Write Research Composer; do
    test -x "$products/$app.app/Contents/MacOS/$app"
    test -f "$products/${app}Kit.framework/Versions/A/${app}Kit"
done
test -f "$products/FolioKit.framework/Versions/A/FolioKit"
for library in FKModelFoundations FKPackageSupport FKXMLSupport; do
    test -f "$products/FolioKit.framework/Frameworks/lib${library}.dylib"
done
for library in FWManuscript FWEditor; do
    test -f "$products/WriteKit.framework/Frameworks/lib${library}.dylib"
done
echo 'Suite build and framework product checks passed; installed runtime layout is not validated.'
