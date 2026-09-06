# Working on Folio

Folio is a Suite workspace with independently versioned Git submodules. Clone the parent repository with `git clone --recurse-submodules <repository-url>`. For an existing checkout, preserve local changes before running `git submodule update --init --recursive`.

Open `Folio.xcworkspace`. Use the shared **Write** or **Research** scheme to run an application, **FolioKit** for framework work, and **Folio** to build or test the entire Suite. The application schemes resolve and embed the workspace's FolioKit build; open the enclosing workspace when developing the applications.

The current skeleton uses Xcode 26.6 and a macOS 26.5 deployment target. `Config/Suite.xcconfig` controls the Suite minimum; each component retains a standalone fallback in its own `Config/Project.xcconfig`. Signing uses the existing project team settings. Contributors may select their own team locally; keep personal signing changes out of shared commits.

## Validation

Run `scripts/check-build.sh` for a fresh unsigned build of the pinned Suite and verification that both applications embed FolioKit. It requires Xcode and initialized submodules, and returns a nonzero status on failure. It does not provision signing or prove application launch, entitlements, or notarization.

For native tests, select **Folio** in Xcode and use Product → Test. The shared `Folio.xctestplan` includes all existing unit and UI test targets. These remain template tests; passing them is not proof of Work Session, persistence, or archival behavior. Add behavioral tests at agreed public interfaces as those features are designed.

## Names and ownership

Bundle and type identifiers live under `net.ctwelve.Folio`. Objective-C prefixes are **FK** for FolioKit, **FW** for Write, and **FR** for Research. The current document subclasses follow those prefixes; other generated application classes may acquire prefixes when developed.

Application document registrations currently describe separate `.folio-write-prototype` and `.folio-research-prototype` SQLite stores. These temporary types are not the native Work package or archival folio specification. The template document classes still own independent persistence stacks. Implementing shared editing requires the helper-owned Work Session model in `docs/architecture/work-session-contract.md` and the lifecycle proof described in issue #13.

## Cross-repository changes

Create a branch in each component being changed and a coordinating branch in the parent when needed. Commit and publish component changes first; then commit their submodule pins in the parent. A parent commit identifies the exact component revisions that form a Suite build. Parent review descriptions should link the component changes and their validation.

Before updating pins, inspect `git status` in the parent and affected components. Updating a parent branch does not automatically update populated submodules; preserve local work before synchronizing them. Keep issue tracking and cross-Suite architecture in this repository, and implementation and symbol documentation alongside their owning code.
