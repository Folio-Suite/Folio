<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Work Session authority and application traffic

Approved through the design interview for [issue #5](https://github.com/ctwelve/Folio/issues/5). Amended by [issue #15](https://github.com/Folio-Suite/Folio/issues/15) to replace central helper ownership with domain hosts. This contract defines behavior; it does not specify production implementation. See [ADR 0004](../adr/0004-helper-owned-work-sessions.md).

## Authority and editing

Write’s domain host owns the authoritative Work Session and accepts requests from multiple Suite applications. Research and Composer govern Source Library and Edition operations through their respective Kits and hosts. Sharing framework binaries does not create shared runtime state. Host packaging and XPC transport remain unselected. Applications own presentation, selections, navigation, windows, and unfinished interaction state; they share such state with the Session only as needed to safeguard data. Explicit reveal/navigation actions may coordinate presentation.

The Session owns accepted semantic state and mediates all mutations. Use the smallest meaningful editing lock for the duration of an interaction, allowing inspection and unrelated edits elsewhere. Structural operations acquire the additional protection they require; avoid global editing mutexes. Requests include sufficient revision context to reject stale assumptions. Accept independent changes and reconcile overlaps only when unambiguous; otherwise preserve the attempted edit for author resolution.

Compound semantic actions succeed or fail as a whole. Structural integrity is mandatory, but incomplete authoring is allowed: missing accessibility descriptions and unresolved Cross-references produce diagnostics rather than preventing saving. Edition configuration and publication review belong to Composer; authoring diagnostics remain available in the relevant editing tools.

Other applications normally display accepted changes. Explicitly marked live previews may expose provisional input, but publication and other operations requiring consistency use accepted state.

## Safety and recovery

An acceptance acknowledgment means the change is recoverable locally. Applications may show provisional edits responsively before acknowledgment. Text input reaches recovery storage incrementally rather than waiting for focus changes or Apply; recoverable drafts remain distinct from accepted semantic state.

If recoverable storage fails, preserve existing state and pending input, announce the failure, stop acknowledging acceptance, and pause further mutations. Offer retry or recovery/export to another location. Do not silently continue accumulating unprotected work.

If an application fails, invalidate its live connection and lock ownership. Reject requests using expired ownership. Process-lifecycle monitoring can inform connection health; exact supervision and detection mechanisms remain open.

If the authority host fails, clients preserve provisional input, show unavailability, and pause mutations. Reconnection reconciles pending requests against durable receipts before resuming, avoiding duplicate application of an accepted change. Automatic recovery and intentional owner shutdown must be distinguishable; exact relaunch and supervision behavior remains to be proved for the domain-host topology.

## Undo and restoration

Undo follows the application editing context and modality that produced an action. The Session validates and performs the reversal; Work-wide history supports inspection and deliberate restoration. If reversal would affect later contributions, explain the consequences and require a choice rather than silently destroying intervening work. Offer a reversal preserving later contributions where possible. [Issue #8](https://github.com/ctwelve/Folio/issues/8) defines the command and durable-history machinery.

Explicit discard or restoration of a Document Version affects the whole Work. Coordinate the operation across applications, make its scope clear before confirmation, and update every connected application to the restored state. Application-specific reversal belongs to Undo.

## Drag and drop

The destination determines the requested semantic operation. Dropping a Figure onto an inspector reveals that Figure; an appropriate Manuscript destination may request insertion or movement. Explicit copying creates a distinct object. The Session validates mutations and preserves identity and relationships.

Cross-Work transfers copy by default, including the assets and semantic information needed for self-containment, new identity, and appropriate provenance. Linking is explicit and remains governed by the Assembly decisions in [issue #9](https://github.com/ctwelve/Folio/issues/9). A cross-Work move secures the destination before removing the source. Relevant native facilities should be investigated without making self-containment dependent on the original Work remaining available.

## Connections, Close, and Quit

A durable restoration association is distinct from a live process connection. Explicitly closing an application's editing context releases its association. Quitting or crashing preserves the association for restoration, but it cannot keep locks, live resources, or the Work resident indefinitely. When the last association is released, the Session safeguards outstanding state and closes the Work. Close Work Everywhere may be available as an explicit convenience.

Owner shutdown must account for outstanding edits and active clients. Closing an owner window does not authorize discarding shared state. Follow native Auto Save and document-close preferences; explicit author-directed discard remains possible through the native document lifecycle. The exact choice of continuing a service, coordinating closure, or another safe owner-lifetime mechanism remains open.

If required saving or serialization fails during coordinated shutdown, preserve the responsible host and affected editing contexts long enough to permit retry, another destination, or cancellation. Successfully saved documents do not justify losing another document's pending work. Forced termination relies on recovery.

Expose pending input, local recoverability, saving, and action-required states in the appropriate application interfaces. Local recoverability does not promise backup or synchronization. No central menu bar application or green-dot presentation is required. Startup, residency, and any login behavior remain service-lifecycle decisions.

## Native document integration and outstanding proofs

Explicit Save persists the native Work package. Exporting a complete archival folio is a separate operation, as established by [ADR 0005](../adr/0005-native-packages-and-archival-folios.md), superseding the original portable-checkpoint-on-Save assumption. Native Works may use external versioned dependencies; the archival folio must be self-contained. Continuous preservation, native document saving, and version creation must form a coherent lifecycle; do not assume that a private journal plus manual archive export supplies native Auto Save and Document Versions.

Apple's `NSDocument.preservesVersions` defaults to `autosavesInPlace`; enabling preservation without autosaving in place is documented as undefined behavior. Native Versions includes browsing, restoration, and restoring a copy. macOS also provides an Ask to keep changes when closing documents preference; automatic saving on close is the default. These facts constrain the proof, but do not establish that a domain-hosted multi-application architecture inherits the behavior automatically.

- [NSDocument.preservesVersions](https://developer.apple.com/documentation/appkit/nsdocument/preservesversions)
- [Browse and restore Document Versions](https://support.apple.com/guide/mac-help/view-and-restore-past-versions-of-documents-mh40710/mac)
- [Desktop & Dock document-close preferences](https://support.apple.com/en-kw/guide/mac-help/-mchlp1119/mac)

[Issue #13](https://github.com/ctwelve/Folio/issues/13) must demonstrate Auto Save, explicit Save, Document Versions browsing/restoration, coherent restoration across connected applications, large-asset behavior, and native package saving with separate archival export and isolated reconstruction. [Issue #4](https://github.com/ctwelve/Folio/issues/4) settles detailed authority and lifecycle behavior from that evidence; the native-package choice is settled.

Further domain-host design must prove recovery versus intentional quit, connection health and lock invalidation, durable request reconciliation, bounded resource residency with preserved associations, and coordinated quit failures. Transport, process supervision, executable packaging, and owner shutdown with active clients remain open. These proofs preserve the safety contract while replacing the former central-helper arrangement.

The current Write and Research implementations provide bounded in-process NSDocument behavior, and Composer is a provisional NSPersistentDocument skeleton. Neither a successful build nor a framework loaded in several apps establishes the cross-application guarantees above. Reuse the public Kit operation boundary for service tests, adding disconnect, stale-request, retry, and shutdown cases when the transport is implemented.
