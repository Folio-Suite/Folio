#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail
cd "$(dirname "$0")/.."
# Fail before an expensive build if an Xcode scheme edit drops a Suite app.
python3 - <<'PYSCHEME'
import xml.etree.ElementTree as ET
scheme = ET.parse('Folio.xcworkspace/xcshareddata/xcschemes/Folio.xcscheme')
built = {entry.find('BuildableReference').get('BlueprintName')
         for entry in scheme.findall('./BuildAction/BuildActionEntries/BuildActionEntry')
         if entry.get('buildForRunning') == 'YES'}
missing = {'Write', 'Research', 'Composer', 'FolioKit'} - built
if missing:
    raise SystemExit('Folio scheme is missing build entries: ' + ', '.join(sorted(missing)))
PYSCHEME
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/folio-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
xcodebuild -workspace "$PWD/Folio.xcworkspace" -scheme Folio -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
products="$build_dir/Build/Products/Debug"
for app in Write Research Composer; do
    test -x "$products/$app.app/Contents/MacOS/$app"
    test -f "$products/${app}Kit.framework/Versions/A/${app}Kit"
done
test -f "$products/FolioKit.framework/Versions/A/FolioKit"
for app in Write Research Composer; do
    test -x "$products/$app.app/Contents/XPCServices/${app}XPCService.xpc/Contents/MacOS/${app}XPCService"
done
python3 scripts/check-kit-interfaces.py "$products"
ruby scripts/release.rb verify --products "$products"
echo 'Suite build and framework product checks passed; installed runtime layout is not validated.'
