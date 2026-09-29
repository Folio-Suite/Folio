<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift cleanup and application composition

This follow-up to the [Swift migration](swift-migration-acceptance.md) implements
[issue #80](https://github.com/Folio-Suite/Folio/issues/80).

## Result

- The six Kits publish Swift modules without authored module maps or public
  Objective-C headers. Storyboard classes use their Swift module and type names.
- FolioKit groups model and package code; WriteKit groups editor and Manuscript
  code; ResearchKit groups its library shell; ComposerKit groups preview code.
- Main-menu storyboards stay with the applications. WriteKit owns the editor,
  ResearchKit owns the library window, and ComposerKit owns the preview window.
  Public factories load Kit resources from their own bundles.
- The Work model resource is `Work.momd/WorkV1.mom`. Its schema, model version
  identifier, document identifiers, and saved package contents are preserved.
  Unused generated app model scaffolds are removed.
- Suite builds retain shared framework deployment. The standalone wrapper embeds
  the current six Kits and package runtimes, removes development-only runtime
  search paths from the final app copies, and verifies their dependencies and
  resources. See [build instructions](../../CONTRIBUTING.md).

## Localization coverage

The extraction check covers all applications, Kits, services, six storyboards,
and three metadata catalogs. Research and Composer scene catalogs moved with
their storyboards, preserving Interface Builder keys and all existing language
values. TypographyKit's structured diagnostic codes retain their documented
technical context; hosts provide localized presentation. Authored text and
identifiers remain unchanged.

The existing Composer preview placeholder translations remain marked
`needs_review`; this cleanup preserves them rather than inventing replacements.
The running preview uses ComposerKit's localized status keys. No new translations
are claimed.

## Verification

Verified locally with Xcode 27 on macOS 27:

- Clean, signed universal Suite build; all 58 native tests passed, with no skips.
  New checks exercise public Kit window factories and document class registration.
  Existing old-writer package fixtures still reopen. A subsequent focused run of
  all 24 WriteKit tests passes, including the custom toolbar image regression.
- External Swift consumers compile for arm64 and x86_64; private declarations
  are rejected, and TypographyKit/UndoKit import independently.
- All six Kit documentation archives build. TypographyKit's independent public
  behavior harness passes.
- Localization extraction and metadata checks pass; 674 compiled Kit storyboard
  translations match the source catalogs.
- Team signing, Hardened Runtime, library validation, and coordinated product
  identities pass for the Suite build.
- Signed standalone builds pass dependency, resource, sandbox-entitlement, and
  signature checks for all three apps. Relocated copies launch without DYLD
  overrides and map their Kits from their embedded frameworks. All three bundled
  services respond with matching nonces from a sandboxed XPC probe.
- The 25 Ruby tooling tests pass (156 assertions). Independent Standards review
  found no issues. Spec review caught five legacy Xcode class-prefix settings;
  those template settings are removed.

Full development CI also builds and checks all three unsigned standalone apps;
signed native tests use the Suite layout. This is development composition
verification, with distribution signing and installed release acceptance remaining
part of release preparation.
