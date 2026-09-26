---
name: folio-appkit
description: Implement and diagnose Folio AppKit interaction and NSTextView/TextKit behavior. Use for responder-chain commands, keyboard focus, window restoration, text selection, layout, editing, and undo integration.
---

<!--
SPDX-FileCopyrightText: 2025 Charles Wiltgen
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio AppKit and TextKit

Selected Axiom material adapted for Folio's native controllers and reusable Kit editors. Read [CONTRIBUTING.md](../../../CONTRIBUTING.md#interface-design) for current storyboard/resource ownership, public Kit interfaces, deployment settings, localization, and native validation. Follow relevant architecture records through [domain.md](../../../docs/agents/domain.md) if the task changes document or host responsibilities.

## Locate the behavior

Trace the affected storyboard scene, controller or view, owning bundle, host window/document, and public Kit entry point. For a bug, establish the input sequence and observable failure. For new behavior, identify the native control or existing command path that should own it. Keep layout in the established storyboard and behavior in its controller/Kit boundary.

- Menus, target/action, keyboard focus, hit testing, or window restoration: read [AppKit interaction](references/appkit-interaction.md).
- Editing, selection, layout performance, undo, Writing Tools, or TextKit compatibility: read [TextKit](references/textkit.md).

Use the current project deployment minimum and verify unfamiliar selectors in the selected SDK or Apple documentation. Check OS availability separately from SDK availability. Adopt a newer API to solve the task with a compatible fallback where needed; a modernization request alone does not select a new UI architecture.

## Verify native behavior

Exercise the changed interaction in its real host. Relevant checks include keyboard-only operation, command enablement in multiple windows, selection and undo, and close/reopen or restoration. Use the native Xcode validation described by the repository and distinguish source inspection from runtime evidence. For a focused accessibility audit, use the installed `appkit-accessibility-auditor` skill; ordinary AppKit work does not require running overlapping full audits.

Report what changed, the behavior observed, and any unverified scenario. Upstream distribution workflows and broad SwiftUI/iOS routing are outside this skill. For source selection and local revisions, read [UPSTREAM.md](UPSTREAM.md).
