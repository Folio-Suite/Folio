# Working on Folio

Folio is a Suite workspace with independently versioned Git submodules. Clone the parent repository with `git clone --recurse-submodules <repository-url>`. For an existing checkout, preserve local changes before running `git submodule update --init --recursive`.

Open `Folio.xcworkspace`. Use the shared **Write** or **Research** scheme to run an application, **FolioKit** for framework work, and **Folio** to build or test the entire Suite. The applications use their domain frameworks, which consume FolioKit. Internal dynamic libraries are embedded in their owning frameworks. The current development schemes assume an installed environment; open the enclosing workspace when developing the applications.

The current skeleton uses Xcode 26.6 and a macOS 26.5 deployment target. `Config/Suite.xcconfig` controls the Suite minimum; each component retains a standalone fallback in its own `Config/Project.xcconfig`. Signing uses the existing project team settings. Contributors may select their own team locally; keep personal signing changes out of shared commits.

## Validation

Build the shared **Folio** scheme in Xcode, or run `xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Debug -destination 'platform=macOS' build` from the parent checkout. The older `scripts/check-build.sh` still asserts direct FolioKit embedding in both applications and does not validate the current installed development arrangement; its packaging checks need revision before reuse.

For the editor and package tests, select **Write** in Xcode and use Product → Test. That scheme includes FolioKitTests, WriteKitTests, WriteTests, and WriteUITests. Start native UI runners through Xcode, or prepare the signed test products with build-for-testing before using the CLI test runner. The shared **Folio** scheme also covers the Research shell, including native file-type discovery, package reopening, and preservation of collected files across saves. Its remaining framework and UI tests are templates. Passing the current tests does not prove cross-application Work Session or archival behavior.

## Names and ownership

Application, framework, test, document-type, and pasteboard identifiers use `dev.foliosuite`. Write declares `dev.foliosuite.Write.Work` (`.fwdoc`); Research declares `dev.foliosuite.Research.Library` (`.frlibrary`). Objective-C prefixes are **FK** for FolioKit, **FW** for Write, and **FR** for Research. The current document subclasses follow those prefixes; other generated application classes may acquire prefixes when developed.

Write's first editor uses `.fwdoc` packages containing a Core Data store, with NSDocument hosting in-process persistence behind WriteKit. Research uses `.frlibrary` packages containing a closed `Library.sqlite` snapshot and preserves additional package members. Its source catalog remains an empty shell. The early Write package schema is documented in `Write/docs/native-work-v1.md`; neither application implements complete archival folio exchange. Separately hosted domain persistence and shared editing still require lifecycle design and proof; the first editor does not settle issue #13 or implement the older helper-owned Work Session contract.

## Cross-repository changes

Create a branch in each component being changed and a coordinating branch in the parent when needed. Commit and publish component changes first; then commit their submodule pins in the parent. A parent commit identifies the exact component revisions that form a Suite build. Parent review descriptions should link the component changes and their validation.

Before updating pins, inspect `git status` in the parent and affected components. Updating a parent branch does not automatically update populated submodules; preserve local work before synchronizing them. Keep issue tracking and cross-Suite architecture in this repository, and implementation and symbol documentation alongside their owning code.
