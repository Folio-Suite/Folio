<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Source Libraries and portable evidence

Approved through the design interview for [issue #7](https://github.com/Folio-Suite/Folio/issues/7), Q1–Q17. [ADR 0007](../adr/0007-independent-source-records-and-reconciliation.md) records the ownership decision. The 2026-09-27 [professional workflow decision](../adr/0014-professional-workspaces-and-optional-source-sync.md) adds a default Library, fuller-research placement, and optional ongoing record synchronization. This contract builds on the [semantic model](semantic-model-contract.md), [Work Session](work-session-contract.md), and [native package and archival folio](archival-folio-contract.md) contracts.

## Shared foundations and responsible applications

Sources and authored text have shared model foundations. Research supplies the fuller Source capabilities, just as Write supplies the fuller capabilities for authored text assembled into a Manuscript. The subsequent [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md) establishes FolioKit as the shared foundation, ResearchKit for Source Library capabilities, and WriteKit for Work capabilities. Concrete Source schemas, operation interfaces, and shared primitive allocation remain further work within that ownership.

Sharing a primitive does not make its uses semantically interchangeable. A captured excerpt, a transcription, and the researcher's commentary may share text capabilities while preserving their distinct meaning and relationships. An excerpt identifies what it was taken from; a transcription identifies what it transcribes; commentary expresses the researcher's thinking. Research highlights on source material remain distinct from editorial Comments on authored text.

## Source identity and records

A Source is an independently citable research object. Different editions and translations are distinct Sources with explicit relationships. A scan ordinarily represents a particular Source rather than becoming a new Source merely because it is another file. Correcting bibliographic metadata preserves Source identity; selecting a different cited edition selects a different Source.

A Source record may contain only bibliographic metadata, such as a title, printing, and ISBN, or describe a large collection of scans, EPUBs, PDFs, and other materials. A Citation does not require a digital reproduction, excerpt, or transcription of a physical source the author consulted. BibTeX is an inspiration for useful minimal bibliographic records, not a selected native storage format.

Source identity is distinct from the identity and revision of each record describing it. Library and Work-local records can retain the same Source identity while having separate ownership and editing histories. Preserve provenance, the originating library reference where applicable, and enough information about the imported state to compare subsequent changes.

Titles and external identifiers can suggest related or duplicate Sources, but do not silently establish relationships or merge identities. Independently created records in different libraries may assign different identities to the same edition. Reconciliation is explicit, preserves provenance and existing Citation targets, and exposes metadata conflicts. Records sharing Source identity can be recognized as related copies without assuming equal contents.

## Libraries and Work-local ownership

A Source Library is a reusable, versioned user document independent of any Work. Offer one default user-wide Library at the Suite's first start, available across applications as a capture destination. It remains an ordinary Source Library Document. Authors may organize multiple Libraries however they choose, but need not do so.

A Library is optional for bibliographic research within a Work. A Work-local record can contain every field needed for correct Citations and references, including translators, editions, identifiers, and specialized fields; "basic" does not prescribe a short fixed field list. Creating fuller reusable research records with PDFs, other attachments, transcriptions, research notes, or relationships among editions leads into a Library. Offer ongoing synchronization when saving the Work-local record there. Work-specific arguments and commentary remain Work-owned authored material. The Work still retains the subset and exact dependencies required to understand and reproduce its own content, including imported material.

Capture outside a Document offers a chosen or remembered Library with its destination visible and changeable, and an option to create a Library. Capture inside Write may remain Work-local. Preserve unfinished capture while resolving an unavailable Library destination. A browser extension or another lightweight interface can enter the same Research capability; its implementation is separate work.

When Write brings a Source into a Work, it copies the subset immediately useful to that task, with identity and a reference to the fuller Research/library context. That Work-local record is independently editable. Bringing in additional data is a deliberate user action. Related editions, translations, or other Sources do not automatically bring their full records or attachments into the Work.

Reusable observations belong with the Source Library; arguments and observations specific to a Work belong with that Work. Commentary uses the same text foundations as Manuscript content. Ordinary copying into a Work produces independently editable authored text with new text identity, preserves provenance, and carries the Citations, Source data, and evidence dependencies needed to make it usable. Reuse a compatible Work-local Source record when available; otherwise bring in the necessary record and dependencies. Source identity survives this transfer even though copied authored text receives new identity. Live reuse remains a separate, explicit advanced operation under the semantic model contract.

## Deliberate reconciliation and optional ongoing synchronization

The editing context determines which record changes. Records remain independently owned and editable. Without an explicitly enabled synchronization relationship, editing the Work-local copy does not alter the Library, and editing the Library does not alter existing Works. Offer changes in either direction for deliberate adoption.

A Library update may notify interested applications that a Source identity has changed. Notification alone is not adoption; automatic adoption requires the persistent, explicitly enabled relationship below. Work mutations continue through the authoritative Work Session, and Library mutations through its own authority. This contract does not choose a transport or redefine document ownership.

Compare relevant data against the last shared state. Offer nonconflicting changes together and expose competing changes for the author to resolve. Fields absent from an intentionally smaller Work-local copy are not deletion requests against the fuller library record. Generation numbers, hashes over relevant subsets, or other mechanisms may support this comparison; no exact algorithm or encoding is selected.

Ongoing synchronization is an explicit, persistent choice for a particular Work-local record and Library record. While enabled, automatically exchange nonconflicting changes in their shared bibliographic information; conflicts require resolution. Additional Library research material does not automatically enter the Work. Distinct editions and translations remain distinct Sources: synchronization does not retarget a Citation to another Source. Composer's selected and pinned snapshots retain their separate update rules.

Incoming changes enter the receiving Document's history. Undo or Redo affecting synchronized fields changes only that Document and pauses synchronization for the affected pair until reconciliation. The reversal must neither cascade to another Document nor be immediately reapplied by synchronization. This preserves document-local Undo while permitting ordinary edits to synchronize when the pair is active.

Removing a record ends the affected relationship and preserves its counterpart. Disabling synchronization preserves both records and their provenance. Explicitly clearing a shared bibliographic field can synchronize as an edit; removing an entire record is a separate operation. Existing Citation and historical dependencies retain their preservation guarantees.

An unavailable Library leaves the Work usable with its retained subset. Show synchronization as pending and reconcile when the same Library becomes available again. The complete Library record remains unavailable; a different Library or independently imported copy must not silently substitute or reconnect. Richer new research still requires a Library destination, with unfinished capture preserved while that destination is resolved.

## Citations, locators, and bibliography membership

One Citation occurrence can contain an ordered group of individual Source references. Each reference retains its own Source identity, locator, and qualifying text. Grouping references in an occurrence does not merge their Source records. Citation styles govern rendered punctuation and ordering conventions while the underlying authored relationships remain structured.

Locators distinguish publication numbering from positions in particular materials. A printed page number may differ from its PDF page position; a passage in a transcription is another target. Support structured locators such as pages, chapters, verses, timestamps, and ranges, along with textual locators where no specialized form applies. Profiles may extend this vocabulary. A Citation may identify a Source and locator without any separately captured evidence object.

Track Citation usage in individual Content Units. An Edition's bibliography normally derives from the Citations in its selected text. Unplaced or omitted text retains its Citations without automatically contributing entries to that Edition. Authors can deliberately include uncited Sources, such as further reading. Removing a bibliography entry or the last Citation does not itself delete the Work's Source record.

The official [Zotero word processor documentation](https://www.zotero.org/support/word_processor_plugin_usage#citations_with_multiple_cited_items) provides a precedent for multiple individually selected items with individual locators, prefixes, and suffixes, with style sorting subject to author control. LaTeX's [biblatex manual](https://mirrors.ctan.org/macros/latex/contrib/biblatex/doc/biblatex.pdf), especially its citation and multicite commands, provides a precedent for separately keyed references with individual qualifying notes. These are design inspirations, not adoption of either implementation or a claim that all LaTeX citation packages behave identically. Grouped bibliography entries are a separate capability and are not selected here.

## Evidence dependencies and portability

Dependencies follow the material actually used. Merely citing a bibliographic record does not require every attachment or a digital reproduction of the cited publication. An excerpt or annotation anchored to a particular file normally makes that file a dependency; authors can deliberately include additional research materials. Research navigation relationships remain distinct from dependencies necessary to understand or reconstruct the Work.

The native Work may retain exact-version external material references. Its independent metadata copies do not require duplicating all source bytes into every working package. A complete archival folio gathers the exact records and necessary materials required across the complete Work, retained history, and explicitly associated Composer Arrangements (including Editions), including dependencies unused by the currently selected Edition. Unrelated libraries, attachments, and related Sources need not be included. The [Project archive decision](../adr/0013-document-lifecycle-and-project-archives.md) also permits a Source Library to be an explicitly selected Document in a Suite-wide `.folio`; its complete owned content and declared history are then part of that archive. Import reconstructs an independent native Library and never silently reconnects it to an existing copy.

Reconstruction uses enclosed records and material versions without requiring the originating library. Reconnection is optional and deliberate. A missing external file retains its identity and references and is reported as unavailable; matching names or newer material never silently substitute. Missing required dependencies prevent a completeness claim under the archival contract.

## Material versions and removal

Replacing a PDF or other attached material creates a new material version while the bibliographic Source may remain the same. Existing excerpts and annotations retain their original targets; replacement carries no promise of migrating highlights or other attachments. Any reassociation must be deliberate and verified. Retain earlier material versions wherever existing dependencies require them.

Removing a Source from a collection is distinct from destroying records or materials needed by Citations or history. Within the dependency graph Folio controls, retain what existing uses require. Work-local copies survive removal of the originating library record. External files may disappear outside Folio's control; disclose the missing dependency while preserving its references.

## Remaining work

Concrete Source schemas, bibliographic field vocabularies, identity encoding, subset selection, comparison and synchronization algorithms, material storage, and notification mechanisms remain implementation work. Exact internal module allocation and Zotero or BibTeX import/export integrations are not selected. Source Library native Versions and recovery integration require focused implementation proof under the lifecycle contract.

Verify through public Kit operations and native workflows: Work-local reference sufficiency, richer-research destination, opt-in paired sync, conflict resolution, omission versus explicit clearing, independent record removal, Undo/Redo pausing without cascading or reapplication, unavailable Library behavior, and no automatic reconnection to an imported copy. The default Library and synchronized records are approved design, not implemented catalog behavior.

Issue #8 supplies the approved semantic command and durable history contract; #4 resolves lifecycle design through the [document lifecycle contract](document-lifecycle-contract.md); #13 was retired as superseded. Focused integration checks belong with the relevant implementation. This contract resolves Source Library and Work-local research ownership without claiming those implementations or proofs complete.
