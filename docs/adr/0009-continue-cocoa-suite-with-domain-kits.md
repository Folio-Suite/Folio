<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Continue the Cocoa Suite with document-domain Kits

Folio serves both a practical publishing need and sustained learning through building software. Continue the existing monorepo toward completion using Objective-C, AppKit storyboards, and visually authored Core Data models; introduce Swift selectively when it provides a concrete benefit. A rewrite, successor repository, SwiftUI/SwiftData replacement, and single-app persona redesign were considered but are not the adopted direction.

Write/WriteKit specializes in Works, Research/ResearchKit in Source Libraries, and Composer/ComposerKit in Editions. FolioKit supplies shared foundations. Keep most domain behavior and reusable presentation in the Kits, with applications responsible for setup and native hosting. These roles do not require every semantic object to become a separate file or application.

An Edition remains a configured expression of a Work and produces Renditions. The complete, shareable archival folio includes the related object types, history, and dependencies required for reconstruction. Edition-to-Work references, revision selection, and the expanded archive graph remain design work; Composer's current document declaration is a provisional skeleton, not that completed contract.

[Issue #15](https://github.com/Folio-Suite/Folio/issues/15) records the alignment. [ADR 0004](0004-helper-owned-work-sessions.md) defines runtime authority and [ADR 0003](0003-distribute-an-integrated-suite.md) separates module design from distribution proof. Preserve existing public Kit test boundaries, with native Xcode tests for document and UI integration. The related lifecycle, history, composition, and distribution work remains open.
