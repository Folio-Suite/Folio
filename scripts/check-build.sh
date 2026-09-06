#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if git submodule status --recursive | /usr/bin/grep -q '^[-+U]'; then
    echo 'Submodules must match the Suite pins. Run git submodule update --init --recursive after preserving local work.' >&2
    exit 1
fi
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/folio-build.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
for app in Write Research; do
    test -d "$build_dir/Build/Products/Debug/$app.app/Contents/Frameworks/FolioKit.framework"
done
