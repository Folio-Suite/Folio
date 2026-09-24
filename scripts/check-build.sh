#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail
cd "$(dirname "$0")/.."
build_actions=(build)
if [[ $# -gt 0 ]]; then
    if [[ $# -ne 1 || "$1" != --analyze ]]; then
        echo 'Usage: scripts/check-build.sh [--analyze]' >&2
        exit 2
    fi
    build_actions=(analyze build)
fi
# Fail before an expensive build if an Xcode scheme edit drops a Suite app.
ruby - <<'RUBYSCHEME'
require 'rexml/document'
scheme = REXML::Document.new(File.read('Folio.xcworkspace/xcshareddata/xcschemes/Folio.xcscheme'))
built = REXML::XPath.match(scheme, './Scheme/BuildAction/BuildActionEntries/BuildActionEntry')
                   .select { |entry| entry.attributes['buildForRunning'] == 'YES' }
                   .map { |entry| entry.elements['BuildableReference'].attributes['BlueprintName'] }
missing = %w[Write Research Composer FolioKit] - built
abort 'Folio scheme is missing build entries: ' + missing.sort.join(', ') unless missing.empty?
RUBYSCHEME
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/folio-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
xcodebuild -workspace "$PWD/Folio.xcworkspace" -scheme Folio -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO "${build_actions[@]}"
products="$build_dir/Build/Products/Debug"
for app in Write Research Composer; do
    test -x "$products/$app.app/Contents/MacOS/$app"
    test -f "$products/${app}Kit.framework/Versions/A/${app}Kit"
done
test -f "$products/FolioKit.framework/Versions/A/FolioKit"
for app in Write Research Composer; do
    test -x "$products/$app.app/Contents/XPCServices/${app}XPCService.xpc/Contents/MacOS/${app}XPCService"
done
ruby scripts/check-kit-interfaces.rb "$products"
ruby scripts/release.rb verify --products "$products"
echo 'Suite build and framework product checks passed; installed runtime layout is not validated.'
