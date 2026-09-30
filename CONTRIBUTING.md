<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Working on Folio

Folio is a monorepo. Clone it with `git clone <repository-url>` and open the workspace at the repository root. The four domain frameworks are separate targets in `Core/Core.xcodeproj`; their sources and unit tests live under `Core/`. Write, Research, and Composer projects retain their applications, services, and app/UI tests. UndoKit and TypographyKit remain standalone frameworks.

Open `Folio.xcworkspace`. Use the shared **Write**, **Research**, or **Composer** scheme to run an application, **Core** to build or test the four domain frameworks, and **Folio** to build or test the entire Suite. Each app links FolioKit, WriteKit, ResearchKit, and ComposerKit. Framework sources compile into their owning targets. Default Suite builds resolve the six Kits from `/Library/Frameworks` and feed the coordinated installer. Use the standalone build command below for an app with its own framework copies. Open the enclosing workspace when developing the applications.

Folio requires **macOS 14 Sonoma or newer** and builds with Xcode 27. `SDKROOT = macosx` selects the installed macOS SDK; using SDK 27 does not raise the deployment minimum. The Suite configuration, component `Project.xcconfig` fallbacks, and targets use `$(RECOMMENDED_MACOSX_DEPLOYMENT_TARGET)`, which resolves to 14.0 with Xcode 27. Recheck this value and compatibility when upgrading Xcode; it follows Apple’s recommendation rather than pinning an OS version. Signing uses the existing project team settings. Contributors may select their own team locally; keep personal signing changes out of shared commits.

Storyboards inherit the project deployment target. Upgrade their serialization
with the current Xcode/Interface Builder tools; keep their object identifiers and
localization keys stable. Resource schema numbers (for example, storyboard `3.0`,
“Xcode 8 format,” Core Data `documentVersion=1.0`, and asset catalog `version=1`)
are file-format identifiers, not OS requirements. Keep the versions emitted by
Apple's tools; Core Data's `minimumToolsVersion=Automatic` uses the current tools.

The shared Kits must be team-signed even during development: the hardened apps
load them directly from the build products directory. Do not accept a recommended
settings change that sets a Kit's `CODE_SIGN_IDENTITY` to an empty value (Do Not
Sign). That leaves a linker-signed framework without a Team ID, which library
validation rejects even when its path is correct. Retain automatic team signing;
`scripts/check-ci-signing.rb` checks this before CI executes tests.

## AI-assisted development

Our [AI skill usage and attribution](docs/ai-skills.md) describes the globally installed engineering, discovery, and accessibility skills, the project-local Cocoa adaptations, and their upstream authors. Global skills are contributor-managed tooling; cloning Folio supplies only its local skills and project conventions. The same architecture, review, and validation requirements apply to AI-assisted changes.

## Validation

Debug uses unoptimized Swift compilation for predictable debugging. Release
uses optimized Swift compilation and dead-code stripping, and
`Config/Suite.xcconfig` disables coverage instrumentation for Release. Keep fast
math disabled for predictable numeric behavior. Consider incremental link-time
optimization only after comparing representative workloads and build times;
there is no measured Folio performance benefit yet. See Apple’s
[build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
for these controls.

Build the shared **Folio** scheme in Xcode, or run `xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug -destination 'platform=macOS' build` from the parent checkout. `scripts/check-build.sh` performs a clean unsigned Suite build and checks application and framework products. It does not validate signing, installed framework resolution, runtime loading, or distribution packaging. Composer includes a bounded, read-only composition preview. Each app embeds its own XPC service skeleton; the build check verifies all three products exist.

To build a sandboxed app with its own dependencies, run `scripts/build-standalone.sh Write --derived-data /tmp/folio-write-standalone` (or `Research`, `Composer`, or `Folio` for all three). Add `--configuration Release` when needed. Use a **different DerivedData path** from Suite builds; Xcode can remove old Suite products when switching build layouts within one DerivedData directory. The wrapper passes `Config/Standalone.xcconfig`, sets `FOLIO_DISTRIBUTION=standalone`, and writes to `Debug-standalone` or `Release-standalone` within that dedicated path. Each app embeds all six Kit frameworks, package runtime frameworks, and its XPC service. The Kits retain their compiled storyboards, models, and assets. The wrapper removes absolute developer and Suite framework search paths from final app copies, re-signs changed code, and verifies the embedded runtime and resource closure. It leaves shared framework build products alone when using the required separate path. Xcode's configured signing identity is used by default; set `FOLIO_SIGNING_IDENTITY` or pass `--identity SIGNER` to select the identity for both Xcode and normalization. `--unsigned` skips signing checks for CI and verifies the configured App Sandbox settings without claiming runtime entitlements. Standalone builds are separate from the Suite installer.

Use the shared **Core** scheme to build or test the four domain framework targets. Use the shared **Write**, **Research**, and **Composer** schemes for their application and UI tests; start native UI runners through Xcode, or prepare signed test products with build-for-testing before using the CLI test runner. The **Folio** scheme checks coordinated Suite integration. Passing current tests does not prove cross-application Work Session or archival behavior.

Full GitHub development CI builds the Folio scheme and runs the Core and three shared app
schemes in parallel on separate Macs. Drafts get repository checks; identical
recently validated source trees can reuse full evidence.
See [Development CI](docs/development-ci.md) for triggers, local reproduction,
and the boundary between CI evidence and release validation.

## Release identity

All apps, Kits, and bundled services inherit the version and build from the shared
Suite configuration, currently **0.1.0 (1)**. Builds and archives leave that
configuration unchanged. Use the Ruby workflow in
[Suite version and build numbering](docs/release-numbering.md) to record and verify
the resulting shipping bundles. See [Suite installer](docs/installer.md) for the
PKG staging command and clean-install proof procedure.

## Names and ownership

Application, framework, test, and pasteboard identifiers use `dev.foliosuite`; document-type identifiers use `app.foliosuite`. Write declares `app.foliosuite.Write.Doc` (`.flwrbundle`); Research declares `app.foliosuite.Research.Doc` (`.flrsbundle`). Composer reserves `app.foliosuite.Composer.Doc` (`.flcpbundle`); its old SQLite document scaffold is no longer registered, and package persistence remains to be implemented. The paired bundle/ZIP declarations and reserved Composer bundle are listed in [document file types](docs/document-file-types.md). ZIP handling is not yet implemented. Public Swift types use domain names; `@objc` runtime names remain only where Cocoa storyboards or document registration require them.

Write's first editor uses `.flwrbundle` packages containing a Core Data store, with NSDocument hosting in-process persistence behind WriteKit. Research uses `.flrsbundle` packages containing a closed `Library.sqlite` snapshot and preserves additional package members. Its source catalog remains an empty shell. The early Write package schema is documented in `docs/architecture/native-work-v1.md`; neither application implements complete archival folio exchange. The approved [document lifecycle](docs/architecture/document-lifecycle-contract.md) selects efficient Core Data working storage, shared on-demand domain hosts, and a Suite-wide `.folio` archive. These require explicit implementation slices; current registrations and snapshot stores do not implement them. Issue #13 remains retired as superseded.

## Coordinated changes

Use one branch for coordinated changes across Core framework targets, Write, Research, and Composer. Commit source, project references, shared schemes, and documentation together so each revision describes a coherent Suite. Keep issue tracking and cross-Suite architecture in this repository, and symbol documentation alongside its owning code.

## Interface design

Keep application and reusable Kit interfaces in storyboards so designers can inspect and edit their layout in Interface Builder. Controllers own behavior and model integration; runtime construction is reserved for genuinely dynamic content.

Write's menus live in `Write/Write/Base.lproj/Main.storyboard`. Its document window, native toolbar, Manuscript sidebar, reusable text editor, inline warning marker and popover, and help content live in `Core/WriteKit/Resources/Base.lproj/Editor.storyboard`, bundled with WriteKit. The native toolbar is attached to the Editor Window scene. Its semantic E icons live in `Core/WriteKit/Resources/Formatting.xcassets`. Edit those scenes to change layout, labels, symbols, and spacing. The editor loads that framework resource explicitly, independent of the host application's main storyboard.

## Localization

Keep user-facing strings in the owning bundle’s catalogs, with stable semantic keys and English defaults. See [Localization](docs/localization.md) for Interface Builder keys, translator context, and the catalog extraction check.

## Data modeling

Use Xcode’s versioned Core Data model editor for persistent schemas. WriteKit’s authoritative model is `Core/WriteKit/Resources/Work.xcdatamodeld`; edit entities, attributes, inverses, ordered relationships, validation, and deletion rules there. The private store adapter loads the compiled model from WriteKit rather than reconstructing the schema in code. Managed objects stay inside that adapter; application callers use the Kit’s public model interface.

The current pre-alpha model replaces the experimental code-defined format without a migration requirement. Model versions remain explicit so compatibility can be governed as the project matures.

## Public Kit interfaces

Follow [ADR 0017](docs/adr/0017-discoverable-swift-interfaces-and-resources.md):
keep each public API in a clearly named file or known set of interface files,
with DocC beside the declarations and an entry-point guide in the module's
README or DocC overview. Keep `AppDelegate.swift` at each app's source root.
Group implementation areas under top-level `Modules/`, alongside `Interface/`
and `Resources/`; module folders do not automatically become separate targets.
Collect bundled resources at the owning app or framework's root or in its
top-level `Resources/` directory. Future internal libraries remain components
of that enclosing product, with resource ownership retained by the product.

All six Kits publish Swift modules. Callers, including each owning application,
use `import KitName` and public Swift declarations. Keep implementation types
internal or private, and keep production callers free of `@testable import`.
Update DocC together with public declarations. Framework source files compile
into their owning target; callers do not add repository source or header paths.

Swift 6 language mode uses explicit isolation: UI owners are `@MainActor`, while
immutable values and pure composition remain nonisolated. Core Data managed
objects stay inside their store adapter. Preserve Objective-C runtime names only
where Cocoa storyboards, document registration, or XPC require interoperability.
The Kits publish Swift modules without authored module maps, umbrella headers,
or generated Objective-C headers. Framework identity and version remain in each
bundle's Info.plist.

UndoKit and TypographyKit have independent projects and shared schemes, target
macOS 14, and build without Folio domain frameworks. `scripts/check-kit-interfaces.rb`
compiles external Swift consumers from built products, rejects exported headers
and private symbols, and imports both independent frameworks in isolation. Apps and Kits
ship as one coordinated Suite version; mixed versions are unsupported.

### Packages and lint

Each project uses Up to Next Major Version requirements with minimum versions
Defaults 9.0.9, swift-collections 1.7.1, swift-algorithms 1.2.1,
and SwiftLintPlugins 0.65.1. Applications and frameworks link the library products;
all native targets run the SwiftLint build plugin. Commit resolved package files
with deliberate upgrades. Use Defaults for preferences, Collections for suitable
data structures, and Algorithms for suitable sequence operations as those needs
arise. Adding a dependency does not imply a new preference or feature.

`.swiftlint.yml` adapts the maintainer's KitchenMemory configuration for AppKit
and the Folio source layout. Each project directory has a small `.swiftlint.yml`
that inherits the root configuration because Xcode's build plugin searches only
within that project directory. Keep shared rules in the root configuration so
command-line and Xcode lint use the same policy. Fix lint errors before review; warnings guide focused
cleanup. The repository build scripts pass `-skipPackagePluginValidation` to run
the resolved SwiftLint plugin in unattended builds. Xcode may ask local
contributors to trust this package plugin when first opening the workspace.

## Kit documentation

FolioKit, WriteKit, ResearchKit, ComposerKit, TypographyKit, UndoKit, and future Kits use DocC at a standard suitable for a public API. Each catalog states the Kit's ownership and boundary, current supported behavior, public import and hosting rules, and material limitations where applicable. Keep claims aligned with public Swift declarations and implemented behavior. Describe planned capabilities as plans, not current APIs. Add examples only for implemented public APIs and verify that they match current callers; scaffold catalogs must not invent examples for unavailable behavior. Document caller-facing contracts beside declarations, and validate generated documentation when interfaces change. See [ADR 0008](docs/adr/0008-public-api-quality-kit-documentation.md) for scope and expectations.

## Licensing

Shared `IDETemplateMacros.plist` files in the workspace and each project configure
Xcode's `FILEHEADER` macro for new Objective-C and Swift source files. They insert
the creation year, `the Folio Project` attribution, and the MIT SPDX identifier.
These templates affect new files; they do not rewrite existing headers or update
copyright years on every build. Files with other comment syntax still need the
appropriate notice from the conventions below.

Folio and its components use the MIT License. Use `the Folio Project` as the copyright holder in project notices and Xcode organization metadata. Add `SPDX-FileCopyrightText: 2026 the Folio Project` (using the appropriate creation year) and `SPDX-License-Identifier: MIT` in the file format’s comment syntax to new project-owned files. Keep shebangs, XML declarations, Xcode encoding markers, and Markdown front matter in their required positions. Do not create license sidecars. Project-owned assets and formats without comments, such as JSON, are covered by the repository’s MIT license. Preserve upstream authorship and license terms for imported `.agents/skills` and the Contributor Covenant in `CODE_OF_CONDUCT.md`.
