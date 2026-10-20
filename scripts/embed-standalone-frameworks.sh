#!/bin/bash
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

set -euo pipefail

case "${FOLIO_DISTRIBUTION:-suite}" in
    suite) exit 0 ;;
    standalone) ;;
    *) echo "Unknown FOLIO_DISTRIBUTION: ${FOLIO_DISTRIBUTION}" >&2; exit 2 ;;
esac

destination_root="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "$destination_root"
for kit in FolioKit WriteKit ResearchKit ComposerKit UndoKit TypographyKit; do
    source="${BUILT_PRODUCTS_DIR}/${kit}.framework"
    destination="${destination_root}/${kit}.framework"
    if [[ ! -f "${source}/Versions/A/${kit}" ]]; then
        echo "Missing standalone framework product: ${source}" >&2
        exit 1
    fi
    rm -rf "$destination"
    /usr/bin/ditto "$source" "$destination"
    # Match Xcode's Code Sign On Copy behavior. Framework targets compile
    # unsigned; the containing app must see signed copies before its own seal.
    # The standalone wrapper signs again after normalizing final load paths.
    if [[ "${CODE_SIGNING_ALLOWED:-YES}" != NO ]]; then
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:?Missing app signing identity}" \
            --timestamp=none "$destination"
    fi
done
