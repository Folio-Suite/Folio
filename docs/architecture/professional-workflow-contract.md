<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Professional workspaces and embedded editing

Approved on 2026-09-27 through [Partition the Suite by professional workflow](https://github.com/Folio-Suite/Folio/issues/10), Q1–Q16 and final confirmation. [ADR 0014](../adr/0014-professional-workspaces-and-optional-source-sync.md) records the decision. These are target behaviors; the current shells do not implement them.

## Applications and reusable capabilities

Write, Research, and Composer retain their established ownership. Each supports a complete professional working session in its domain, including users primarily researching, editing another person's work, or designing and producing publications. A user need not operate all three application interfaces to do useful work in one of them.

Kits own substantive behavior and reusable, storyboard-authored presentation. An embedded editor uses the owning Kit's capabilities with presentation suited to the immediate task. A full application supplies a coherent workspace for sustained work. Every host uses supported public interfaces and does not manipulate another Kit's private controls. Owner preferences and host-specific presentation retain the distinctions in [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md).

A further standalone application requires a sustained activity with an independently useful workspace and a clear user-facing purpose. A new semantic type, complex editor, framework, or helper process is insufficient on its own. The possible Project-management application and `.foliobundle` remain deferred.

## Workflow placement

| Activity | Primary workspace and reusable presentation |
| --- | --- |
| Work authoring and substantive editing | Write; reusable Work editors through WriteKit |
| Mathematics, tables, Citations, Cross-references, and other specialized content | Editors in the relevant Document context, ranging from inline controls and inspectors to substantial editor windows |
| Editorial review | Dedicated Work review in Write and Arrangement/Edition review in Composer, with reusable presentation for Comments and Proposed Revisions |
| Source collection and enrichment | Research; reusable capture, Source Record editing, and import capabilities through ResearchKit |
| Semantic Write Profile authoring | Write |
| Composer Profile, Page Template, and comprehensive Theme design | Composer; reusable definition editors with representative preview content, without requiring a finished publication |
| Arrangement/Edition construction and production | Composer, including validation, diagnostics, output jobs, and batch publication |
| Historical comparison, checkpoints, and recovery | The Document's owning Kit exposes the interface; hosts can offer compact views or a substantial history window |

These assignments establish the workspaces, not final screen layouts or a separate framework target for every editor. Detailed design-tool boundaries and terminology may become clearer during implementation. Shared capabilities do not change ownership: a ResearchKit editor for a Work-local Source Record still edits the Work.

Research annotations retain their own meaning. Editorial review addresses Comments and Proposed Revisions, while history examines accepted changes over time. A larger editor or history window retains its relationship to the containing Document and its history.

## Visible editing context and handoff

Editing within the same Document feels continuous regardless of which Kit supplies a tool. Crossing into another Document requires an explicit action identifying the target, followed by a persistent indication of the active editing context. The interface must make Undo, Save, and restoration scope understandable without repeated confirmation prompts. Exact controls remain implementation design work.

The affected material determines Document and command scope. Editing a Work-local Source Record changes the Work; editing its Library counterpart changes the Source Library. Editing an Arrangement's local material versus its source Work is an explicit choice. The [history](semantic-history-contract.md), [Arrangement](arrangement-contract.md), and [lifecycle](document-lifecycle-contract.md) contracts continue to govern those changes.

An explicit handoff, such as continuing in Research, reveals the same Document and object in the full application, preserving a useful selection or navigation target where possible. The original workspace remains available until the user closes it. Handoff connects to the same authoritative Document; it does not create a copy, reconcile records, or change ownership. Shared hosts preserve capability lifetime independently of an application's interface.

## Capture and fuller research

Capture can begin within Write or through a lightweight entry point such as a browser extension. Research owns the fuller research capability. Extensions and companion interfaces are possible entry points, not a commitment to ship a particular integration during migration.

Offer an ordinary default user-wide Source Library at the Suite's first start and make it available across applications. Users may choose other Libraries; multiple Libraries are not required. Capture outside a Document offers a selected or remembered Library with a visible, changeable destination and a creation option when needed. Preserve unfinished capture while an unavailable destination is resolved.

Inside Write, a Work-local Source Record is sufficient for complete bibliographic references. Richer reusable research leads into a Library, with an offer of ongoing synchronization after saving the record there. The [Source Library contract](source-library-contract.md) specifies subset, ownership, and opt-in synchronization rules. Distinct editions remain separate Sources even if author and title match.

## Utilities and helper processes

Research hosts capture, import, and source processing. Composer hosts production checks and output jobs. Commands, extensions, or small companion interfaces may remove a concrete workflow interruption. A visible companion needs a user-facing purpose; a background helper serves execution and lifecycle requirements. Neither automatically becomes another full Suite application.

The selected [shared domain-host lifecycle](document-lifecycle-contract.md) remains authoritative. Loading a framework into multiple processes does not itself share state, and a lightweight interface does not introduce another document authority.

## Implementation and verification

Use the agreed public Kit interfaces and native document/UI workflows. Verify same-document embedded edits, visibly targeted cross-document edits, handoff to the same object, independent owner-interface lifetime, and the actual Document affected by Undo and Save. Verify capture destination, Work-local sufficiency, richer Library material, and optional sync through the Source Library contract's observable scenarios.

Use native keyboard and accessibility checks for active-context indication, embedded editors, review/history navigation, and handoff. Successful framework compilation does not establish those interactions. Detailed layouts, Source schemas, sync algorithms and transport, browser-extension integration, and reusable definition storage remain focused implementation design work. The [migration and Suite roadmap](../plans/swift-migration-and-suite-roadmap.md) proposes the sequence; it is not authorization to execute it.
