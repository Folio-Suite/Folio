<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Xcode 27 and macOS 27: Apple-source review

Reviewed 2026-09-24 for the Objective-C/AppKit/Core Data Suite established by
[ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md). This is research,
not an adopted configuration change or a runtime acceptance report.

## Verified Xcode 27 changes

- **Architectures:** Xcode itself requires Apple silicon. A deployment minimum of
  macOS 27 changes `ARCHS_STANDARD` to omit Intel; the macOS 27 SDK still supports
  Universal apps deploying to macOS 12 or later. Keep SDK adoption separate from
  Folio's minimum-OS decision.
- **Linker:** `-ld_classic` is removed. Check custom linker flags during upgrades.
- **Localization:** export now extracts localization macros from headers;
  a `do not translate` comment marks exclusions. Review extraction diffs while
  preserving Folio's English-baseline policy.
- **Testing:** test plans can choose UI-test crash severity; a launch-test template
  exercises supported UI configurations. Preserve failure-level crash reporting.
- **Tools:** MCP gains scheme, destination, debugger, and build-setting controls.
  The workspace-independent server remains described as a preview; evaluate
  separately from project migration.
- **Interface Builder:** the new simulator-independent compilation mode concerns
  UIKit documents, not Folio's AppKit storyboards.
- **Icons:** Icon Composer 2.0 adds rendering controls and previews for both design
  generations; useful when revisiting Suite icons.

Source: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes),
sections Intel Deprecation, Linking, Localization, Testing, Coding Intelligence,
Interface Builder, and Icon Composer.

## macOS 27 checks relevant to Folio

- **Editor:** `NSTextView` now uses gesture-based `NSTextSelectionManager`;
  existing `mouseDown:` overrides retain a compatibility path. Recheck selection,
  dragging, scrolling, and keyboard interaction.
- **Menus:** SDK-27-linked apps automatically hide symbol and non-symbol menu
  images. Image-only items need explicit `preferredImageVisibility`. The
  `NSTextView` Layout Orientation submenu also moves under Font.
- **Packages:** open-panel content-type/package settings now update file/directory
  selection flags. Exercise native Work and Source Library open/save workflows.
- **Installer:** unspecified `hostArchitecture` now means arm64. Check installer
  scripts and architecture promises when validating distribution.
- **Optional APIs:** segmented controls and toolbar groups gain semantic roles,
  including tabs; `NSRefreshController` supplies scroll-view refresh. Adopt only
  for an actual navigation or refresh requirement.
- **Future drag handling:** promised-file reception must occur during designated
  drag-operation callbacks; custom gesture recognizers must implement
  `locationInView:`.

Source: [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes),
sections AppKit and Rosetta. The later AppKit resolved-issue entry clarifies that
SDK-27-linked apps hide non-symbol images too; the earlier new-feature paragraph
alone is incomplete.

## Particularly useful accessibility opportunity

`XCUIVoiceOverService` can enable VoiceOver, navigate focus, and retrieve spoken
output from Objective-C UI tests. A small editor/sidebar/toolbar test would add
evidence beyond accessibility labels. The installed Mac XCUIAutomation headers
declare macOS 27 availability on both the class and `XCUIDevice.voiceOverService`.
Use availability gating if the test suite still runs on macOS 26.

Source: [XCUIVoiceOverService](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice?language=objc).
Local corroboration:
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Versions/A/Headers/XCUIVoiceOverService.h`
and `XCUIDevice.h`. No test was implemented or run for this research note.

## Useful earlier feature, not new in 27

Compilation caching was introduced in Xcode 26 for Swift and C-family languages,
especially repeated clean builds and branch switching. Benchmark it for Folio
before making it a shared setting. Type-safe String Catalog symbols also arrived
in 26 and are Swift-specific; they do not replace Folio's Objective-C localization
macros. [Xcode 26 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes).

## Evidence limits

Apple's current release-note pages have final release titles. Their Markdown
representations were read directly because the web renderer could not consume
the linked `text/markdown` responses. Search results and individual API pages
can retain beta labels; prefer the current release notes and installed SDK
availability declarations. This review found no basis for replacing AppKit,
storyboards, or Core Data. It does not establish Apple's indefinite roadmap,
nor infer language-feature policy from framework changes.

## Folio configuration and build audit

Local evidence gathered on 2026-09-24:

- Selected tools: Xcode 27.0 (`27A266a`), macOS SDK 27.0, host macOS 27.0
  (`26A428`). `SDKROOT = macosx` already selects the new SDK.
- `Config/Suite.xcconfig` and all four component fallback configurations retain
  macOS 26.5. Effective Release settings for the four Suite scheme build entries
  resolve to `arm64 x86_64`. Raising the minimum is a separate product decision.
- Explicit Clang modules are already enabled Suite-wide; the four Kits enable
  module verification. ARC, weak references, strict Objective-C message sending,
  availability warnings, and extensive compiler warnings are already configured.
- Project upgrade markers remain at 2660, and `CONTRIBUTING.md` names Xcode 26.6.
  Refresh the documented toolchain and review Xcode's recommended settings before
  recording a new upgrade marker; changing the marker itself enables no feature.
- Write's Format menu includes Strong Emphasis, Underline, and Strikethrough
  images. Decide whether their visibility should be explicitly preserved under
  SDK 27. The labels remain present, so this is not evidence of blank menu items.
- The editor uses `NSLayoutManager` for temporary highlighting and layout.
  New TextKit 2 viewport and attachment-reuse APIs in `NSTextView.h` are future
  evaluation candidates, not immediate configuration switches for this editor.
- `scripts/package.rb` currently emits a component package with `pkgbuild`, not
  a product Distribution XML. Review architecture handling at product-installer
  work; the release-note change alone does not prove this package is broken.

Validation used a disposable copy to preserve the existing modified build number
and FolioKit scheme. The copy required its own Git metadata for the build-number
lock. With normal Xcode service/cache access, `bash scripts/check-build.sh`
passed: clean Debug Suite build, published Kit interface checks, application and
XPC products, and coordinated bundle identity. No compiler `warning:` or `error:`
diagnostics were found in the successful log. Ruby emitted warnings about two
Xcode-provided `SWIFT_DEBUG_INFORMATION_*` environment variables; these did not
fail the check. Logs: `/tmp/folio-xcode27-build.log`; effective Release settings:
`/tmp/folio-xcode27-settings.json`. Temporary evidence is not a release artifact.

No native tests, Release build, installed launch, or macOS 26.5 runtime check was
performed. No project configuration or application source was changed.

Recommended order: retain the current deployment minimum while adopting the
installed SDK; refresh toolchain documentation/review recommended settings; run
native editor and package regressions on 27; add a focused Objective-C VoiceOver
test; then benchmark compilation caching and revisit icon rendering as separate
improvements. Preserve existing localization policy when checking header
extraction. These are recommendations, not adopted architecture decisions.
