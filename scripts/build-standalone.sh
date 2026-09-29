#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail

usage() {
    echo 'Usage: scripts/build-standalone.sh Write|Research|Composer|Folio --derived-data PATH [--configuration Debug|Release] [--unsigned] [--identity SIGNER]' >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
scheme=$1
shift
case "$scheme" in
    Write|Research|Composer|Folio) ;;
    *) usage ;;
esac

configuration=Debug
derived_data=
unsigned=false
identity="${FOLIO_SIGNING_IDENTITY:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --derived-data)
            [[ $# -ge 2 ]] || usage
            derived_data=$2
            shift 2
            ;;
        --configuration)
            [[ $# -ge 2 ]] || usage
            configuration=$2
            shift 2
            ;;
        --unsigned)
            unsigned=true
            shift
            ;;
        --identity)
            [[ $# -ge 2 ]] || usage
            identity=$2
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$derived_data" ]] || usage
case "$configuration" in Debug|Release) ;; *) usage ;; esac

repo_root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$derived_data"
derived_data=$(cd "$derived_data" && pwd)
shared_products="$derived_data/Build/Products/$configuration"
for product in Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework \
               ComposerKit.framework UndoKit.framework TypographyKit.framework; do
    if [[ -e "$shared_products/$product" ]]; then
        echo "Use a separate DerivedData path: $shared_products contains Suite product $product" >&2
        exit 2
    fi
done
build_settings=(ONLY_ACTIVE_ARCH=NO)
if $unsigned; then
    build_settings+=(CODE_SIGNING_ALLOWED=NO)
elif [[ -n "$identity" ]]; then
    build_settings+=("CODE_SIGN_IDENTITY=$identity")
fi

xcodebuild -workspace "$repo_root/Folio.xcworkspace" -scheme "$scheme" \
    -configuration "$configuration" -destination 'platform=macOS' \
    -derivedDataPath "$derived_data" -xcconfig "$repo_root/Config/Standalone.xcconfig" \
    -skipPackagePluginValidation "${build_settings[@]}" build

products="$derived_data/Build/Products/$configuration-standalone"
if [[ "$scheme" == Folio ]]; then
    apps=(Write Research Composer)
else
    apps=("$scheme")
fi
for app in "${apps[@]}"; do
    if $unsigned; then
        ruby "$repo_root/scripts/normalize-standalone-rpaths.rb" "$products/$app.app" --unsigned
        ruby "$repo_root/scripts/check-standalone-app.rb" "$products/$app.app" --unsigned
    else
        if [[ -n "$identity" ]]; then
            ruby "$repo_root/scripts/normalize-standalone-rpaths.rb" "$products/$app.app" --identity "$identity"
        else
            ruby "$repo_root/scripts/normalize-standalone-rpaths.rb" "$products/$app.app"
        fi
        ruby "$repo_root/scripts/check-standalone-app.rb" "$products/$app.app"
    fi
done
