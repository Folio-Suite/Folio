<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Semantic operations and durable document history

Approved through the design interview for [issue #8](https://github.com/Folio-Suite/Folio/issues/8). See [ADR 0010](../adr/0010-document-undo-and-durable-history.md). This records intended behavior, not implemented persistence or automation guarantees.

## Ownership and ordinary Undo

Each independently saved document owns one durable history and one ordering of accepted undoable actions. This follows the native document boundary, not individual files inside a package or the application displaying it. A Work and a Source Library have independent histories. The subsequent [Arrangement contract](arrangement-contract.md) establishes independently saved Composer Arrangements, including Editions, with their own histories; their source Works retain separate histories. This supersedes the earlier Work-owned Edition configuration assumption.

Undo and Redo use familiar native behavior and follow the document, including the author's edits made through automation or another application. This supersedes the originating-application/context rule in the earlier Work Session contract. Native controls may handle unfinished local interactions; accepted document edits share document-wide ordering. The Session validates reversals and preserves structural integrity. No global Undo, linked reversal machinery, or selective cross-application Undo is required.

Cross-document transfers retain their data-preservation requirements, including securing a destination before source removal. Each document independently owns its resulting edits and Undo; Undo does not silently mutate another document.

With durable history enabled, ordinary Undo survives closing and reopening. Undo records a reversal rather than erasing the original action; Redo is likewise recorded. Editing after Undo preserves the abandoned wording in branching history even when ordinary Redo is no longer available.

## History, checkpoints, and restoration

Automatically retain meaningful accepted changes, including deleted material, and support author-named checkpoints. Design for very large histories. Exact typing/action consolidation, retention recommendations, pruning policy, and Time Machine-like behavior remain deferred.

A checkpoint captures a coherent state at the independently saved document boundary, including its owned content and exact dependency versions. A Work checkpoint includes unplaced content and research records; a Composer Arrangement checkpoint includes its owned snapshots, elaborations, and production configuration. Cross-document checkpoint coordination is not implied. It does not imply an archival export or independent backup.

Restoring a checkpoint or native Document Version establishes a new current state while retaining the displaced history as a branch. Record the restored state and its origin; ordinary restoration must not silently delete later accepted work. The native lifecycle prototype must prove this behavior across connected applications.

Authors can recover selected historical material as a new undoable edit, preserving provenance, without restoring the whole document. History-browser UX and whether its presentation belongs in the primary application or its Kit are later decisions.

## Recording settings and deliberate omission

The global history default is On. Each document has Use Global Setting, On, or Off; an explicit override persists with the document, while an inheriting document follows changes to the global setting.

Off disables durable automatic editing-history recording, not ordinary Undo/Redo during the open session or recovery protection for current work. Undo persistence across ordinary closing and reopening is not promised while Off. Existing history remains unless explicitly removed. Named checkpoints remain available. Re-enabling recording starts a new baseline and must not imply that intervening edits were recorded.

Offer an explicit Remove Existing History action. Omit History is also available during an explicit save and any folio export. Expressed author intent overrides default history preservation: saving with omission may overwrite the current document. A copy may be proposed, but overwrite must remain an available direct choice.

A successful overwrite with omission removes historical states and action records, establishes the current state as a new baseline, and clears live Undo/Redo in every connected editing context for that document. Failed saving preserves existing history. Ordinary saving preserves history unless omission is selected. Omission is a one-time operation; subsequent recording follows the effective global/document setting.

Omission preserves current Comments, unresolved Proposed Revisions, and attribution belonging to current content. Snapshots and elaborations required by current Arrangements remain current dependencies and must also survive omission, as specified by the [Arrangement contract](arrangement-contract.md). Removing current editorial material is a separate choice. Removal applies to the saved document or exported artifact and, for an overwrite, its active Folio history. Existing native Document Versions, backups, and prior exports are unaffected; this is not a secure-erasure guarantee.

A history-omitted folio is valid and reconstructs the current Work with its required dependencies. Its manifest explicitly declares history omitted, and it cannot claim complete historical reconstruction. Export preserves history by default. This qualifies the mandatory-history rule in ADR 0005 without weakening dependency or current-content preservation requirements.

## Semantic operations and automation

Interactive editing and automation use the same semantic operation contract: validation, local recoverability before acceptance, structural integrity, attribution, and Undo. Automation is the author acting through another channel, not a separate contributor or privileged mutation path.

An explicitly compound semantic operation succeeds or fails as a whole with an actionable failure result. A caller can explicitly choose separate operations and their individual results. Folio does not infer a transaction around an entire external script or workflow. Each exposed semantic operation supplies sensible Undo grouping; an explicit batch operation can supply one atomic undoable action. Persistence must prove these guarantees, including effects beyond database records; no particular Core Data mechanism is selected here.

Every requested action has a stable identity for internal delivery/recovery reconciliation. An internal retry retains that identity and returns the recorded outcome rather than applying an accepted change twice. Each normal automation invocation is a new request, even when its arguments match a previous invocation.

Identity machinery must preserve the native operation, invocation, and result conventions of AppleScript/OSAScript, Automator, Shortcuts, and other adapters. Authors need not manage transport identities in their scripts. Exact integrations remain implementation work.

Record the acting author, the tool or script used, action identity, and time. The tool's developer does not thereby become an author of the Work. Preserve imported attribution with its provenance rather than representing it as independently verified.

## Editorial material and the baton

Durable history records actions; Proposed Revisions represent wording or structural changes awaiting an editorial decision. Creating, modifying, accepting, and rejecting proposals are undoable actions. Proposed wording remains distinct from accepted Manuscript content until accepted; preserve the proposer's attribution upon acceptance.

Passing the editorial baton does not accept, reject, rewrite, or reattribute Comments or Proposed Revisions. They remain exactly as recorded in the document. The handoff mechanism remains separate design work.

## Remaining proofs

Exact storage schemas, branching algorithms, native Undo persistence, history scale, consolidation and retention, automation adapters, cross-process reconciliation, and UI placement remain implementation or further design work. Native save/restore, recovery, and archival reconstruction proofs remain with #13 and #4. This contract does not select event sourcing or require replaying historical commands to reconstruct current state.
