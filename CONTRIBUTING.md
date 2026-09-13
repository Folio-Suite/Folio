<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Working on Folio

Folio is a monorepo. Clone it with `git clone <repository-url>` and open the workspace at the repository root. FolioKit, Write, and Research retain separate Xcode projects and module ownership within this checkout.

Open `Folio.xcworkspace`. Use the shared **Write** or **Research** scheme to run an application, **FolioKit** for framework work, and **Folio** to build or test the entire Suite. The applications use their domain frameworks, which consume FolioKit. Internal dynamic libraries are embedded in their owning frameworks. Each application embeds its domain framework and FolioKit, including their internal libraries, so the built application can launch outside Xcode. Open the enclosing workspace when developing the applications.

The current skeleton uses Xcode 26.6 and a macOS 26.5 deployment target. `Config/Suite.xcconfig` controls the Suite minimum; each component retains a standalone fallback in its own `Config/Project.xcconfig`. Signing uses the existing project team settings. Contributors may select their own team locally; keep personal signing changes out of shared commits.

## Validation

Build the shared **Folio** scheme in Xcode, or run `xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug -destination 'platform=macOS' build` from the parent checkout. `scripts/check-build.sh` performs a clean unsigned Suite build and checks the current framework/library embedding layout. It does not validate signing, runtime loading, or distribution packaging.

For the editor and package tests, select **Write** in Xcode and use Product → Test. That scheme includes FolioKitTests, WriteKitTests, WriteTests, and WriteUITests. Start native UI runners through Xcode, or prepare the signed test products with build-for-testing before using the CLI test runner. The shared **Folio** scheme also covers the Research shell, including native file-type discovery, package reopening, and preservation of collected files across saves. Its remaining framework and UI tests are templates. Passing the current tests does not prove cross-application Work Session or archival behavior.

## Names and ownership

Application, framework, test, document-type, and pasteboard identifiers use `dev.foliosuite`. Write declares `dev.foliosuite.Write.Work` (`.fwdoc`); Research declares `dev.foliosuite.Research.Library` (`.frlibrary`). Objective-C prefixes are **FK** for FolioKit, **FW** for Write, and **FR** for Research. The current document subclasses follow those prefixes; other generated application classes may acquire prefixes when developed.

Write's first editor uses `.fwdoc` packages containing a Core Data store, with NSDocument hosting in-process persistence behind WriteKit. Research uses `.frlibrary` packages containing a closed `Library.sqlite` snapshot and preserves additional package members. Its source catalog remains an empty shell. The early Write package schema is documented in `docs/architecture/native-work-v1.md`; neither application implements complete archival folio exchange. Separately hosted domain persistence and shared editing still require lifecycle design and proof; the first editor does not settle issue #13 or implement the older helper-owned Work Session contract.

## Coordinated changes

Use one branch for coordinated changes across FolioKit, Write, and Research. Commit source, project references, shared schemes, and documentation together so each revision describes a coherent Suite. Keep issue tracking and cross-Suite architecture in this repository, and symbol documentation alongside its owning code.

## Interface design

Keep application and reusable Kit interfaces in storyboards so designers can inspect and edit their layout in Interface Builder. Controllers own behavior and model integration; runtime construction is reserved for genuinely dynamic content.

Write's menus live in `Write/Write/Base.lproj/Main.storyboard`. Its document window, native toolbar, Manuscript sidebar, reusable text editor, inline warning marker and popover, and help content live in `Write/WriteKit/Resources/Base.lproj/Editor.storyboard`, bundled with WriteKit. The native toolbar is attached to the Editor Window scene. Its semantic E icons live in `Write/WriteKit/Resources/Formatting.xcassets`. Edit those scenes to change layout, labels, symbols, and spacing. The editor loads that framework resource explicitly, independent of the host application's main storyboard.

## Localization

Keep user-facing strings in the owning bundle’s catalogs, with stable semantic keys and English defaults. See [Localization](docs/localization.md) for Interface Builder keys, translator context, and the catalog extraction check.

## Data modeling

Use Xcode’s versioned Core Data model editor for persistent schemas. WriteKit’s authoritative model is `Write/WriteKit/Resources/FWWork.xcdatamodeld`; edit entities, attributes, inverses, ordered relationships, validation, and deletion rules there. The private store adapter loads the compiled model from WriteKit rather than reconstructing the schema in code. Managed objects stay inside that adapter; application callers use the Kit’s public model interface.

The current pre-alpha model replaces the experimental code-defined format without a migration requirement. Model versions remain explicit so compatibility can be governed as the project matures.

## Kit documentation

FolioKit, WriteKit, ResearchKit, and future Kits use DocC at a standard suitable for a public API. Document caller-facing contracts alongside declarations and provide module introductions and useful examples in each Kit's catalog. New or changed interfaces include documentation and generated-documentation validation in the same change. See [ADR 0008](docs/adr/0008-public-api-quality-kit-documentation.md) for scope and expectations.

## Licensing

Folio and its components use the MIT License. Use `the Folio Project` as the copyright holder in project notices and Xcode organization metadata. Add `SPDX-FileCopyrightText: 2026 the Folio Project` (using the appropriate creation year) and `SPDX-License-Identifier: MIT` in the file format’s comment syntax to new project-owned files. Keep shebangs, XML declarations, Xcode encoding markers, and Markdown front matter in their required positions. For formats without comments, such as JSON, use an adjacent `<filename>.license` file. Preserve upstream authorship and license terms for imported `.agents/skills` and the Contributor Covenant in `CODE_OF_CONDUCT.md`.
