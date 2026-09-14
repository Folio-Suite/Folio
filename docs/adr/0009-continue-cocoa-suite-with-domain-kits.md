<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Continue the Cocoa Suite with document-domain Kits

Folio serves both a practical publishing need and sustained learning through building software. Continue the existing monorepo toward completion using Objective-C, AppKit storyboards, and visually authored Core Data models; introduce Swift selectively when it provides a concrete benefit. A rewrite, successor repository, SwiftUI/SwiftData replacement, and single-app persona redesign were considered but are not the adopted direction.

Write/WriteKit specializes in Works, Research/ResearchKit in Source Libraries, and Composer/ComposerKit in Arrangements, including Editions. FolioKit supplies shared foundations. Keep most domain behavior and reusable presentation in the Kits, with applications responsible for setup and native hosting. These roles do not require every semantic object to become a separate file or application.

An Edition remains a configured expression of a Work and produces Renditions. The complete, shareable archival folio includes the related object types, history, and dependencies required for reconstruction. The subsequent [Arrangement contract](../architecture/arrangement-contract.md) settles ownership, revision selection, and archival associations; their implementation remains open; Composer's current document declaration is a provisional skeleton, not that completed contract.

[Issue #15](https://github.com/Folio-Suite/Folio/issues/15) records the alignment. [ADR 0004](0004-helper-owned-work-sessions.md) defines runtime authority and [ADR 0003](0003-distribute-an-integrated-suite.md) separates module design from distribution proof. Preserve existing public Kit test boundaries, with native Xcode tests for document and UI integration. The related lifecycle, history, composition, and distribution work remains open.

## Explicit Kit interfaces

Every host, including a Kit's owning application, consumes the same public interface. Applications remain context containers and coordinators, with room for their own preferences UI and other unique presentation. Kits own domain behavior and reusable, storyboard-authored editors. Hosts configure supported editor interactions rather than relying on internal controls. This preserves locality for editing rules without prescribing an MVVM class for every controller.

The owning application edits persistent preferences. Its Kit must be able to read and apply those preferences in another host even when the owning application is not running. Host configuration is separate: a host may adjust explicitly supported presentation options for its editor instance without changing owner preferences. This is the design contract for future preferences work; a shared preferences store and notification mechanism are not implemented by the initial interface refactor.

Public headers are enumerated in checked-in Clang module maps alongside each Kit’s umbrella header, with module support and explicit module builds enabled in the shared build configuration. Xcode's public-header membership and each Kit's umbrella must agree with that list. Internal headers are private implementation. Any future embedded library remains private to its owning Kit; callers use the Kit interface. This is a supported compile-time interface, not Objective-C runtime isolation or a security mechanism.

Separate implementation libraries need demonstrated reuse. The September 2026 consolidation compiles the existing model, persistence, editor, and foundation sources directly into their owning frameworks, alongside their resources. Named internal modules such as FWManuscript retain their source folders and responsibility boundaries, so they can become libraries later if needed. This supersedes the internal-library target split in the first native shell specification; a future library remains an option when it provides concrete reuse.

Apps and Kits are built, distributed, and supported as a coordinated Suite version. Out-of-alignment versions are explicitly unsupported. Documented public interfaces do not promise independent binary compatibility. Installation-time or launch-time mismatch detection is separate distribution work.

Validation checks the actual published headers and module maps, rejects private imports, and compiles and links an outside caller with only built framework bundles available. Native editor and document tests retain their role in proving resource loading, text editing, and undo behavior. Public interface checks do not establish cross-process Work Session authority, extension support, or installed runtime resolution.

[ADR 0011](0011-composer-arrangements-and-editions.md) subsequently establishes Composer-owned Arrangements and the self-contained Edition Profile, scoped Profiles, and explicit archival associations. It supersedes earlier Work-owned Arrangement/Edition assumptions while preserving independent document histories.
