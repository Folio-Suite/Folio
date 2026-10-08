<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Adopt idiomatic Swift while retaining the Cocoa Suite

**Ownership decision refined:** [ADR 0019](0019-undokit-package-boundary.md)
tracks UndoKit source through a submodule while retaining its independent
repository, native Xcode project, and versioning. The historical acceptance
below records the decision and scope at that time; ADR 0019 governs the current
source, workspace, and release boundary.

Accepted by the maintainer on 2026-09-27 in the review of [the migration specification](https://github.com/Folio-Suite/Folio/issues/29). Reimplement the existing Suite in idiomatic Swift while retaining AppKit/storyboards, Core Data, Core Text, the three professional applications, and their public domain Kits. The Objective-C learning objective is fulfilled; stronger data modeling and consistency with the maintainer's other projects now justify migration while the implementation is still small. Target macOS 14 Sonoma and Intel/Apple Silicon with the agreed native and runtime acceptance evidence.

TypographyKit owns reusable text composition above Core Text; ComposerKit owns publication meaning and coordination. Preserve the working editor, supported Documents, native Undo, public test seams, and historical typography evidence. The first usable composition operation accepts explicit decisions and returns immutable geometry, source mappings and diagnostics; full paragraph optimization, languages, mathematical layout and production outputs follow separately.

UndoKit is a Swift framework developed inside Folio, serving Folio first and KitchenMemory second. Preserve generic history capabilities and storage safeguards while hosts retain meaning, validation, compensation, accepted outcomes, recovery evidence and policy. Module independence is required; external binary distribution and independently usable Objective-C interfaces are deferred until after a working Folio Suite 1.0. The original repository may be deleted after its useful source, Git history, design, research and issue records are verified in Folio. Its unresolved recovery and history decisions continue in Folio's tracker.

A helper-app project will be created only if a concrete need arises. No helper utility, persistent Project manager, or external-framework release project is a prerequisite for the current architecture or migration.

This supersedes ADR 0009's Objective-C-first language policy and header-specific public-interface prescription. Its domain ownership, Kit presentation, coordinated Suite delivery and public-consumer boundaries remain in force. It refines ADR 0012's typography allocation and records acceptance of the migration sequence following ADRs 0013–0014. The [roadmap](../plans/swift-migration-and-suite-roadmap.md) and [ticket handoff](../plans/accepted-backlog.md) carry the staged work. This decision authorizes the plan; this planning session makes no production implementation change.
