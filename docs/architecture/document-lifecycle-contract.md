<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Native document lifecycle

Approved on 2026-09-27 through [issue #4](https://github.com/Folio-Suite/Folio/issues/4), Q1–Q22 and final confirmation. [ADR 0013](../adr/0013-document-lifecycle-and-project-archives.md) records the decision. This contract refines the [Work Session](work-session-contract.md), [semantic history](semantic-history-contract.md), and [archival folio](archival-folio-contract.md) contracts. It describes intended behavior, not implemented service or persistence guarantees.

## Native boundaries and storage

| Owning domain | Independently saved Document | Native package |
| --- | --- | --- |
| Write | One Work, including its Manuscript and unplaced content | `.flwrbundle` |
| Research | One Source Library | `.flrsbundle` |
| Composer | One Arrangement, including an Edition | `.flcpbundle` |

Each Document has its own Save, Undo, history, and checkpoint boundary. Other Suite applications may present and request edits through the owning Kit and authoritative host; their UI does not acquire a second owner for the data. A Project connects the parts selected for an archive without combining their histories. No new Layout entity is introduced.

Core Data is the native working-store foundation. Domain Kits own persistence and schema meaning. Native packages hold files directly and may refer to exact-version external dependencies. Ordinary Save and Auto Save must avoid rebuilding unchanged document content or rewriting unchanged large assets. XML conversion of the Project belongs to archival export. Sharing package utilities does not require identical schemas across domains.

Write now stages native saves by cloning a closed SQLite store and reconciling changed authored content, with an independent-copy fallback. Its opt-in V2 package preserves unchanged opaque resources through the same staging boundary; see [native Work storage](native-work-v1.md). The FileWrapper convenience still produces a complete snapshot. Research retains its package wrapper and collected files around an empty catalog shell. Preserve current package readers and behavior while introducing efficient storage through explicit, tested implementation slices; neither a bundle extension nor a successful Core Data save establishes the full lifecycle contract.

## Shared authority and host lifetime

Use shared, on-demand domain hosts for the logged-in user. Requesting Work capabilities from Composer can activate the Write-domain host without opening Write's interface. Quitting Write's interface leaves active Composer clients working. Other domains follow the same rule. Existing embedded XPC service scaffolds do not establish this shared authority.

Per-user LaunchAgents provide a platform mechanism for this hosting direction. Executable packaging, registration, XPC protocols, client authentication, and supervision remain implementation design work. Respect operating-system service controls and report unavailable capabilities. Framework binaries shared by multiple processes do not share in-memory state.

Maintain one authoritative Folio writer per native Document instance. The host mediates semantic requests, narrowly scoped editing locks, revision checks, and durable acceptance. Applications retain presentation and provisional interaction state. Durable request receipts reconcile retries after interruption without applying an accepted action twice.

When no active client needs a Document, safeguard outstanding state and release resident resources. Durable restoration associations survive app exit without holding locks or keeping documents resident indefinitely. Explicitly closing an editing context releases its association. Closing an owner window does not discard another client's accepted work. If the last client's coordinated close or quit cannot safeguard the Document, retain the responsible host and affected editing context for retry, another destination, or cancellation. Forced termination uses the established recovery path.

The [Work Session safety rules](work-session-contract.md) continue to govern incremental recovery of typing, recoverable drafts distinct from accepted state, expired locks, stale requests, failed storage, and coordinated restoration. Show pending input, local recoverability, saving, and action-required states where relevant.

## Save, checkpoints, Versions, and backup

Save and Auto Save persist consistent accepted native state. Acceptance already promises local recoverability; it does not mean that every edit has completed a native save, a backup, or synchronization. A failed save must not acknowledge success or discard pending work.

An explicit Save does not create a named semantic checkpoint. Creating a checkpoint durably records a coherent state of that Document and ensures it is saved. It does not export a folio or create a Project-wide transaction.

Native Document Versions provide file-level snapshots. Folio's semantic history supplies accepted-action ordering, branches, and named checkpoints; Source Library revisions identify semantic object versions. These remain distinct. Keep native Auto Save and Versions integrated with authoritative domain state rather than substituting a private recovery journal for the native document experience.

Folio-managed restoration of a checkpoint or native Document Version establishes a new current state, retains displaced history as a branch, records the origin, and updates every connected editing context. Explicit history removal remains governed by the history contract. AppKit's default replacement and Undo behavior does not supply that branch-retention policy automatically.

Time Machine is an external backup facility. If an external tool replaces a closed package, Folio can preserve displaced newer history only when another copy survives. No guarantee of recovering absent data is implied. Omit History never erases external backups or previously saved native Versions.

## Format compatibility and capabilities

Distinguish package format, domain schema, required capabilities, and application version. A higher version number alone does not determine safe editing. New features declare the capabilities needed for inspection, editing/reconstruction, and reproduction, with scope appropriate to an object or the whole Document.

Prompt when a compatibility limitation affects use. Allow editing only when required rules are understood and unfamiliar content can be preserved correctly. A local limitation may make one object read-only; a fundamental requirement may make the whole Document read-only. Offer supported inspection or extraction, and refuse an operation that cannot interpret the necessary structure safely. Consent does not make an unsupported edit safe. Any deliberate conversion that loses information produces a separately identified copy.

Newer software encountering an older native format offers upgrade, supported compatibility mode, or cancellation. Editable compatibility mode retains that format through Save and Auto Save and disables unrepresentable features across connected apps. Where a maintained writer is unavailable, label the available inspection as read-only; do not imply editable compatibility. Maintaining a migration path does not require indefinitely maintaining every historical writer.

Every publicly supported released native format retains a migration path without requiring an obsolete Folio installation. The deliberately discarded pre-alpha test formats remain excluded. Preserve current supported documents during the Swift migration. Prefer compatible evolution and document semantic changes explicitly.

## Upgrade and failure behavior

An approved in-place upgrade preserves a recoverable original while preparing and validating the conversion. Replace the native package only after successful preparation; failure leaves the original usable. Offer upgrading a separate copy as an alternative. After verified successful upgrade, the temporary rollback material may be discarded. Permanent downgrade support and permanent old-format copies are not required.

Importing an archive already authorizes necessary supported conversion into the current native formats. It does not authorize overwriting existing Documents or dropping unsupported meaning. Capability limitations still require disclosure. Export/import provides interchange, not a guarantee that an older reader can understand newer features.

Coordinate native file access and use appropriate cooperating locks. When an unexpected external replacement or incompatible change is detected while a Document is open, pause its writes, safeguard active state and pending input, and offer reconciliation or preservation of both versions. Ordinary saving must not silently overwrite that replacement. Direct, uncoordinated modification of an open package is unsupported. File locks are advisory and cannot guarantee prevention or immediate detection of arbitrary external modification.

## Implementation and focused verification

Implement through public Kit operations and native document/UI workflows, extending the agreed seams for shared hosts and archive exchange. Checks should cover save failure and unchanged-resource preservation; client disconnect, stale requests, durable retry reconciliation and last-client quit; native Versions restoration with history retention; old-format upgrade/compatibility/cancellation; unsupported capabilities; and detected external replacement. Verify the actual installed hosting and native integration where those behaviors are claimed.

Exact Core Data schemas, storage algorithms, protocol definitions, service packaging, and conformance schemas remain follow-up work. [Issue #29](https://github.com/Folio-Suite/Folio/issues/29) must reflect this approved direction while retaining separate migration review and implementation acceptance. [Issue #13](https://github.com/Folio-Suite/Folio/issues/13) remains retired; a broad Core Data durability, stress, or File Provider qualification campaign is not a prerequisite.

## Platform basis

- [NSDocument Versions](https://developer.apple.com/documentation/appkit/nsdocument/preservesversions): preservation depends on autosaving in place; enabling it without that behavior is undefined.
- [Document saving](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/DocBasedAppProgrammingGuideForOSX/StandardBehaviors/StandardBehaviors.html) and [file wrappers](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileWrappers/FileWrappers.html): native saving and unchanged file reuse need deliberate integration.
- [LaunchAgents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) and [SMAppService](https://developer.apple.com/documentation/ServiceManagement/SMAppService): per-user service hosting and registration; availability does not prove Folio's integration.
- [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter) and [advisory locking](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/flock.2.html): cooperation does not prevent arbitrary low-level modification.
- [Core Data SQLite snapshots](https://developer.apple.com/library/archive/qa/qa1809/_index.html): a live store's main file cannot be casually separated from required journal state.
