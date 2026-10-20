#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail

# These debugger settings are not inputs to the code-signing tools.
unset SWIFT_DEBUG_INFORMATION_FORMAT SWIFT_DEBUG_INFORMATION_VERSION

# Framework targets compile without a signing identity. The host scheme prepares
# shared development products only after all parallel framework builds finish.
# Standalone distribution signs copies during embedding and after normalization.
if [[ "${CODE_SIGNING_ALLOWED:-YES}" == NO || "${FOLIO_DISTRIBUTION:-suite}" == standalone ]]; then
    exit 0
fi

identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
    # Scheme actions expose evaluated settings but may omit the resolved signing
    # identity. Reuse the certificate of the host Xcode has just signed instead
    # of guessing among development identities installed in the keychain.
    host="${TARGET_BUILD_DIR:?Missing host build directory}/${FULL_PRODUCT_NAME:?Missing signed host}"
    if [[ ! -d "$host" ]]; then
        # A framework-only Build does not build its test host. Run/Test builds
        # the host first; the signing gate verifies preparation before execution.
        echo 'Frameworks compiled; signatures will be prepared when their host is built.'
        exit 0
    fi
    /usr/bin/codesign --verify --strict "$host"
    certificate_dir=$(mktemp -d "${TMPDIR:-/tmp}/folio-signing.XXXXXX")
    trap 'rm -rf "$certificate_dir"' EXIT
    /usr/bin/codesign --display --extract-certificates="${certificate_dir}/certificate-" "$host"
    if [[ ! -f "${certificate_dir}/certificate-0" ]]; then
        echo 'Shared development frameworks require a team-signed host or test target.' >&2
        exit 1
    fi
    identity=$(/usr/bin/shasum -a 1 "${certificate_dir}/certificate-0" | /usr/bin/awk '{print $1}')
fi
if [[ "$identity" == - ]]; then
    echo 'Shared development frameworks require a team signing identity.' >&2
    exit 1
fi

products="${BUILT_PRODUCTS_DIR:?Missing build products directory}"
for kit in FolioKit WriteKit ResearchKit ComposerKit TypographyKit UndoKit; do
    framework="${products}/${kit}.framework"
    [[ -d "$framework" ]] || continue
    /usr/bin/codesign --force --sign "$identity" --timestamp=none "$framework"
    /usr/bin/codesign --verify --strict "$framework"
done
