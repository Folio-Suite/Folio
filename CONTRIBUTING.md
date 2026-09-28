<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Working on Folio

Folio is a monorepo. Clone it with `git clone <repository-url>` and open the workspace at the repository root. The four domain frameworks are separate targets in `Core/Core.xcodeproj`; their sources and unit tests live under `Core/`. Write, Research, and Composer projects retain their applications, services, and app/UI tests. UndoKit and TypographyKit remain standalone frameworks.

Open `Folio.xcworkspace`. Use the shared **Write**, **Research**, or **Composer** scheme to run an application, **Core** to build or test the four domain frameworks, and **Folio** to build or test the entire Suite. Each app links FolioKit, WriteKit, ResearchKit, and ComposerKit. Framework sources compile into their owning targets. Application linking and embedding are being configured for an installed shared-framework deployment. A successful build does not establish that an app is self-contained or that its installed dependencies resolve outside Xcode. Open the enclosing workspace when developing the applications.

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

Debug uses unoptimized Objective-C compilation for predictable debugging. Release
uses Xcode’s size-conscious `-Os` optimization and dead-code stripping, and
`Config/Suite.xcconfig` disables coverage instrumentation for Release. Keep fast
math disabled for predictable numeric behavior. Consider incremental link-time
optimization only after comparing representative workloads and build times;
there is no measured Folio performance benefit yet. See Apple’s
[build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
for these controls.

Build the shared **Folio** scheme in Xcode, or run `xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug -destination 'platform=macOS' build` from the parent checkout. `scripts/check-build.sh` performs a clean unsigned Suite build and checks application and framework products. It does not validate signing, installed framework resolution, runtime loading, or distribution packaging. Composer and its tests remain skeletons. Each app embeds its own XPC service skeleton; the build check verifies all three products exist.

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

Application, framework, test, and pasteboard identifiers use `dev.foliosuite`; document-type identifiers use `app.foliosuite`. Write declares `app.foliosuite.Write.Doc` (`.flwrbundle`); Research declares `app.foliosuite.Research.Doc` (`.flrsbundle`). Composer reserves `app.foliosuite.Composer.Doc` (`.flcpbundle`); its old SQLite document scaffold is no longer registered, and package persistence remains to be implemented. The paired bundle/ZIP declarations and reserved Composer bundle are listed in [document file types](docs/document-file-types.md). ZIP handling is not yet implemented. Objective-C prefixes are **FK** for FolioKit, **FW** for Write, **FR** for Research, and **FC** for Composer. The current document subclasses follow those prefixes; other generated application classes may acquire prefixes when developed.

Write's first editor uses `.flwrbundle` packages containing a Core Data store, with NSDocument hosting in-process persistence behind WriteKit. Research uses `.flrsbundle` packages containing a closed `Library.sqlite` snapshot and preserves additional package members. Its source catalog remains an empty shell. The early Write package schema is documented in `docs/architecture/native-work-v1.md`; neither application implements complete archival folio exchange. The approved [document lifecycle](docs/architecture/document-lifecycle-contract.md) selects efficient Core Data working storage, shared on-demand domain hosts, and a Suite-wide `.folio` archive. These require explicit implementation slices; current registrations and snapshot stores do not implement them. Issue #13 remains retired as superseded.

## Coordinated changes

Use one branch for coordinated changes across Core framework targets, Write, Research, and Composer. Commit source, project references, shared schemes, and documentation together so each revision describes a coherent Suite. Keep issue tracking and cross-Suite architecture in this repository, and symbol documentation alongside its owning code.

## Interface design

Keep application and reusable Kit interfaces in storyboards so designers can inspect and edit their layout in Interface Builder. Controllers own behavior and model integration; runtime construction is reserved for genuinely dynamic content.

Write's menus live in `Write/Write/Base.lproj/Main.storyboard`. Its document window, native toolbar, Manuscript sidebar, reusable text editor, inline warning marker and popover, and help content live in `Core/WriteKit/Resources/Base.lproj/Editor.storyboard`, bundled with WriteKit. The native toolbar is attached to the Editor Window scene. Its semantic E icons live in `Core/WriteKit/Resources/Formatting.xcassets`. Edit those scenes to change layout, labels, symbols, and spacing. The editor loads that framework resource explicitly, independent of the host application's main storyboard.

## Localization

Keep user-facing strings in the owning bundle’s catalogs, with stable semantic keys and English defaults. See [Localization](docs/localization.md) for Interface Builder keys, translator context, and the catalog extraction check.

## Data modeling

Use Xcode’s versioned Core Data model editor for persistent schemas. WriteKit’s authoritative model is `Core/WriteKit/Resources/FWWork.xcdatamodeld`; edit entities, attributes, inverses, ordered relationships, validation, and deletion rules there. The private store adapter loads the compiled model from WriteKit rather than reconstructing the schema in code. Managed objects stay inside that adapter; application callers use the Kit’s public model interface.

The current pre-alpha model replaces the experimental code-defined format without a migration requirement. Model versions remain explicit so compatibility can be governed as the project matures.

## Public Kit interfaces

UndoKit and TypographyKit are independent framework scaffolds with their own
shared schemes. They target macOS 14 and can build without the enclosing Suite.
TypographyKit uses Swift 6 with explicit isolation and publishes its generated
Swift module. Swift interfaces use access control and DocC; the explicit-header
rules below apply to Objective-C interfaces. The interface check also links
isolated Swift consumers of both frameworks and an Objective-C UndoKit consumer.

Every host, including the owning application, uses the Kit's public headers. The
explicit list lives in `<Kit>.modulemap` alongside each Kit’s umbrella header. When deliberately adding
an interface, update that map, the Kit umbrella, Xcode's Public header membership,
and DocC together. Keep implementation headers at Project visibility; do not
publish them as Private headers or add repository header search paths to callers.
Implementation sources compile into their owning Core framework target. Separate libraries require
demonstrated reuse; if introduced, their interfaces remain private to their owning
Kit unless deliberately adopted as a separate public boundary.

`Config/Suite.xcconfig` enables modules and explicit module builds. The normal
`scripts/check-build.sh` also checks actual exported headers, rejects private
imports, and compiles/links an outside consumer without repository header maps.
Apps and Kits must be from the same coordinated Suite version; mixed versions are
unsupported. See [ADR 0009](docs/adr/0009-continue-cocoa-suite-with-domain-kits.md)
for the distinction between owner preferences and per-host presentation settings.

## Kit documentation

FolioKit, WriteKit, ResearchKit, ComposerKit, TypographyKit, UndoKit, and future Kits use DocC at a standard suitable for a public API. Each catalog states the Kit's ownership and boundary, current supported behavior, public import and hosting rules, and material limitations where applicable. Keep claims aligned with exported headers and implemented behavior. Describe planned capabilities as plans, not current APIs. Add examples only for implemented public APIs and verify that they match current callers; scaffold catalogs must not invent examples for unavailable behavior. Document caller-facing contracts beside declarations, and validate generated documentation when interfaces change. See [ADR 0008](docs/adr/0008-public-api-quality-kit-documentation.md) for scope and expectations.

## Licensing

Shared `IDETemplateMacros.plist` files in the workspace and each project configure
Xcode's `FILEHEADER` macro for new Objective-C and Swift source files. They insert
the creation year, `the Folio Project` attribution, and the MIT SPDX identifier.
These templates affect new files; they do not rewrite existing headers or update
copyright years on every build. Files with other comment syntax still need the
appropriate notice from the conventions below.

Folio and its components use the MIT License. Use `the Folio Project` as the copyright holder in project notices and Xcode organization metadata. Add `SPDX-FileCopyrightText: 2026 the Folio Project` (using the appropriate creation year) and `SPDX-License-Identifier: MIT` in the file format’s comment syntax to new project-owned files. Keep shebangs, XML declarations, Xcode encoding markers, and Markdown front matter in their required positions. Do not create license sidecars. Project-owned assets and formats without comments, such as JSON, are covered by the repository’s MIT license. Preserve upstream authorship and license terms for imported `.agents/skills` and the Contributor Covenant in `CODE_OF_CONDUCT.md`.
