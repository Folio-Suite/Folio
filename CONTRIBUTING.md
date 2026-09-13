<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Working on Folio

Folio is a monorepo. Clone it with `git clone <repository-url>` and open the workspace at the repository root. FolioKit, Write, Research, and Composer retain separate Xcode projects and module ownership within this checkout.

Open `Folio.xcworkspace`. Use the shared **Write**, **Research**, or **Composer** scheme to run an application, **FolioKit** for framework work, and **Folio** to build or test the entire Suite. The applications use their domain frameworks, which consume FolioKit. Implementation sources compile directly into their owning frameworks. Application linking and embedding are being configured for an installed shared-framework deployment. A successful build does not establish that an app is self-contained or that its installed dependencies resolve outside Xcode. Open the enclosing workspace when developing the applications.

The current skeleton uses Xcode 26.6 and a macOS 26.5 deployment target. `Config/Suite.xcconfig` controls the Suite minimum; each component retains a standalone fallback in its own `Project.xcconfig`. Signing uses the existing project team settings. Contributors may select their own team locally; keep personal signing changes out of shared commits.

## Validation

Build the shared **Folio** scheme in Xcode, or run `xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug -destination 'platform=macOS' build` from the parent checkout. `scripts/check-build.sh` performs a clean unsigned Suite build and checks application and framework products. It does not validate signing, installed framework resolution, runtime loading, or distribution packaging. Composer and its tests remain skeletons. Each app embeds its own XPC service skeleton; the build check verifies all three products exist.

For the editor and package tests, select **Write** in Xcode and use Product → Test. That scheme includes FolioKitTests, WriteKitTests, WriteTests, and WriteUITests. Start native UI runners through Xcode, or prepare the signed test products with build-for-testing before using the CLI test runner. The shared **Folio** scheme also covers the Research shell, including native file-type discovery, package reopening, and preservation of collected files across saves. Its remaining framework and UI tests are templates. Passing the current tests does not prove cross-application Work Session or archival behavior.

## Release identity

All apps, Kits, and bundled services inherit the version and build from the shared
Suite configuration. The Folio scheme advances the build number once per Build or
Archive action; component schemes leave it unchanged. Use the Ruby workflow in
[Suite version and build numbering](docs/release-numbering.md) to record and verify
the resulting shipping bundles.

## Names and ownership

Application, framework, test, document-type, and pasteboard identifiers use `dev.foliosuite`. Write declares `dev.foliosuite.Write.Work` (`.fwdoc`); Research declares `dev.foliosuite.Research.Library` (`.frlibrary`). Composer declares `dev.foliosuite.Composer.Edition` (`.fcedition`), handled by `FCDocument`. Composer currently retains the template SQLite-backed `NSPersistentDocument` representation, not a native package; Edition package persistence remains to be implemented. Objective-C prefixes are **FK** for FolioKit, **FW** for Write, **FR** for Research, and **FC** for Composer. The current document subclasses follow those prefixes; other generated application classes may acquire prefixes when developed.

Write's first editor uses `.fwdoc` packages containing a Core Data store, with NSDocument hosting in-process persistence behind WriteKit. Research uses `.frlibrary` packages containing a closed `Library.sqlite` snapshot and preserves additional package members. Its source catalog remains an empty shell. The early Write package schema is documented in `docs/architecture/native-work-v1.md`; neither application implements complete archival folio exchange. Separately hosted domain persistence and shared editing still require lifecycle design and proof; the first editor does not settle issue #13 or implement the domain-hosted Work Session contract.

## Coordinated changes

Use one branch for coordinated changes across FolioKit, Write, Research, and Composer. Commit source, project references, shared schemes, and documentation together so each revision describes a coherent Suite. Keep issue tracking and cross-Suite architecture in this repository, and symbol documentation alongside its owning code.

## Interface design

Keep application and reusable Kit interfaces in storyboards so designers can inspect and edit their layout in Interface Builder. Controllers own behavior and model integration; runtime construction is reserved for genuinely dynamic content.

Write's menus live in `Write/Write/Base.lproj/Main.storyboard`. Its document window, native toolbar, Manuscript sidebar, reusable text editor, inline warning marker and popover, and help content live in `Write/WriteKit/Resources/Base.lproj/Editor.storyboard`, bundled with WriteKit. The native toolbar is attached to the Editor Window scene. Its semantic E icons live in `Write/WriteKit/Resources/Formatting.xcassets`. Edit those scenes to change layout, labels, symbols, and spacing. The editor loads that framework resource explicitly, independent of the host application's main storyboard.

## Localization

Keep user-facing strings in the owning bundle’s catalogs, with stable semantic keys and English defaults. See [Localization](docs/localization.md) for Interface Builder keys, translator context, and the catalog extraction check.

## Data modeling

Use Xcode’s versioned Core Data model editor for persistent schemas. WriteKit’s authoritative model is `Write/WriteKit/Resources/FWWork.xcdatamodeld`; edit entities, attributes, inverses, ordered relationships, validation, and deletion rules there. The private store adapter loads the compiled model from WriteKit rather than reconstructing the schema in code. Managed objects stay inside that adapter; application callers use the Kit’s public model interface.

The current pre-alpha model replaces the experimental code-defined format without a migration requirement. Model versions remain explicit so compatibility can be governed as the project matures.

## Public Kit interfaces

Every host, including the owning application, uses the Kit's public headers. The
explicit list lives in `<Kit>.modulemap` alongside each Kit’s umbrella header. When deliberately adding
an interface, update that map, the Kit umbrella, Xcode's Public header membership,
and DocC together. Keep implementation headers at Project visibility; do not
publish them as Private headers or add repository header search paths to callers.
Implementation sources compile into the owning Kit. Separate libraries require
demonstrated reuse; if introduced, their interfaces remain private to their owning
Kit unless deliberately adopted as a separate public boundary.

`Config/Suite.xcconfig` enables modules and explicit module builds. The normal
`scripts/check-build.sh` also checks actual exported headers, rejects private
imports, and compiles/links an outside consumer without repository header maps.
Apps and Kits must be from the same coordinated Suite version; mixed versions are
unsupported. See [ADR 0009](docs/adr/0009-continue-cocoa-suite-with-domain-kits.md)
for the distinction between owner preferences and per-host presentation settings.

## Kit documentation

FolioKit, WriteKit, ResearchKit, ComposerKit, and future Kits use DocC at a standard suitable for a public API. Document caller-facing contracts alongside declarations and provide module introductions and useful examples in each Kit's catalog. New or changed interfaces include documentation and generated-documentation validation in the same change. See [ADR 0008](docs/adr/0008-public-api-quality-kit-documentation.md) for scope and expectations.

## Licensing

Shared `IDETemplateMacros.plist` files in the workspace and each project configure
Xcode's `FILEHEADER` macro for new Objective-C and Swift source files. They insert
the creation year, `the Folio Project` attribution, and the MIT SPDX identifier.
These templates affect new files; they do not rewrite existing headers or update
copyright years on every build. Files with other comment syntax still need the
appropriate notice from the conventions below.

Folio and its components use the MIT License. Use `the Folio Project` as the copyright holder in project notices and Xcode organization metadata. Add `SPDX-FileCopyrightText: 2026 the Folio Project` (using the appropriate creation year) and `SPDX-License-Identifier: MIT` in the file format’s comment syntax to new project-owned files. Keep shebangs, XML declarations, Xcode encoding markers, and Markdown front matter in their required positions. For formats without comments, such as JSON, use an adjacent `<filename>.license` file. Preserve upstream authorship and license terms for imported `.agents/skills` and the Contributor Covenant in `CODE_OF_CONDUCT.md`.
