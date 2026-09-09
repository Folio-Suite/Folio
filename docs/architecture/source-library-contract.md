<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Source Libraries and portable evidence

Approved through the design interview for [issue #7](https://github.com/Folio-Suite/Folio/issues/7), Q1–Q17. [ADR 0007](../adr/0007-independent-source-records-and-reconciliation.md) records the ownership decision. This contract builds on the [semantic model](semantic-model-contract.md), [Work Session](work-session-contract.md), and [native package and archival folio](archival-folio-contract.md) contracts.

## Shared foundations and responsible applications

Sources and authored text have shared model foundations. Research supplies the fuller Source capabilities, just as Write supplies the fuller capabilities for authored text assembled into a Manuscript. FolioKit is the base; additional Kits may implement these major areas as they develop. Exact framework names, interfaces, and allocation remain open.

Sharing a primitive does not make its uses semantically interchangeable. A captured excerpt, a transcription, and the researcher's commentary may share text capabilities while preserving their distinct meaning and relationships. An excerpt identifies what it was taken from; a transcription identifies what it transcribes; commentary expresses the researcher's thinking. Research highlights on source material remain distinct from editorial Comments on authored text.

## Source identity and records

A Source is an independently citable research object. Different editions and translations are distinct Sources with explicit relationships. A scan ordinarily represents a particular Source rather than becoming a new Source merely because it is another file. Correcting bibliographic metadata preserves Source identity; selecting a different cited edition selects a different Source.

A Source record may contain only bibliographic metadata, such as a title, printing, and ISBN, or describe a large collection of scans, EPUBs, PDFs, and other materials. A Citation does not require a digital reproduction, excerpt, or transcription of a physical source the author consulted. BibTeX is an inspiration for useful minimal bibliographic records, not a selected native storage format.

Source identity is distinct from the identity and revision of each record describing it. Library and Work-local records can retain the same Source identity while having separate ownership and editing histories. Preserve provenance, the originating library reference where applicable, and enough information about the imported state to compare subsequent changes.

Titles and external identifiers can suggest related or duplicate Sources, but do not silently establish relationships or merge identities. Independently created records in different libraries may assign different identities to the same edition. Reconciliation is explicit, preserves provenance and existing Citation targets, and exposes metadata conflicts. Records sharing Source identity can be recognized as related copies without assuming equal contents.

## Libraries and Work-local ownership

A Source Library is a reusable, versioned user document independent of any Work. Authors may organize multiple libraries however they choose. A library is optional: research may begin inside a Work and later enter a library while preserving identity and provenance.

When Write brings a Source into a Work, it copies the subset immediately useful to that task, with identity and a reference to the fuller Research/library context. That Work-local record is independently editable. Bringing in additional data is a deliberate user action. Related editions, translations, or other Sources do not automatically bring their full records or attachments into the Work.

Reusable observations belong with the Source Library; arguments and observations specific to a Work belong with that Work. Commentary uses the same text foundations as Manuscript content. Ordinary copying into a Work produces independently editable authored text with new text identity, preserves provenance, and carries the Citations, Source data, and evidence dependencies needed to make it usable. Reuse a compatible Work-local Source record when available; otherwise bring in the necessary record and dependencies. Source identity survives this transfer even though copied authored text receives new identity. Live reuse remains a separate, explicit advanced operation under the semantic model contract.

## Deliberate reconciliation

The editing context determines which record changes. Editing the Work-local copy does not silently alter the library, and editing the library does not silently alter existing Works. Offer changes in either direction for deliberate adoption.

A library update may notify interested open applications that a Source identity has changed, allowing an offer to share the relevant changes. Notification is not adoption. Work mutations continue through the authoritative Work Session; this contract does not choose a notification transport or redefine authority.

Compare relevant data against the last shared state. Offer nonconflicting changes together and expose competing changes for the author to resolve. Fields absent from an intentionally smaller Work-local copy are not deletion requests against the fuller library record. Generation numbers, hashes over relevant subsets, or other mechanisms may support this comparison; no exact algorithm or encoding is selected.

## Citations, locators, and bibliography membership

One Citation occurrence can contain an ordered group of individual Source references. Each reference retains its own Source identity, locator, and qualifying text. Grouping references in an occurrence does not merge their Source records. Citation styles govern rendered punctuation and ordering conventions while the underlying authored relationships remain structured.

Locators distinguish publication numbering from positions in particular materials. A printed page number may differ from its PDF page position; a passage in a transcription is another target. Support structured locators such as pages, chapters, verses, timestamps, and ranges, along with textual locators where no specialized form applies. Profiles may extend this vocabulary. A Citation may identify a Source and locator without any separately captured evidence object.

Track Citation usage in individual Content Units. An Edition's bibliography normally derives from the Citations in its selected text. Unplaced or omitted text retains its Citations without automatically contributing entries to that Edition. Authors can deliberately include uncited Sources, such as further reading. Removing a bibliography entry or the last Citation does not itself delete the Work's Source record.

The official [Zotero word processor documentation](https://www.zotero.org/support/word_processor_plugin_usage#citations_with_multiple_cited_items) provides a precedent for multiple individually selected items with individual locators, prefixes, and suffixes, with style sorting subject to author control. LaTeX's [biblatex manual](https://mirrors.ctan.org/macros/latex/contrib/biblatex/doc/biblatex.pdf), especially its citation and multicite commands, provides a precedent for separately keyed references with individual qualifying notes. These are design inspirations, not adoption of either implementation or a claim that all LaTeX citation packages behave identically. Grouped bibliography entries are a separate capability and are not selected here.

## Evidence dependencies and portability

Dependencies follow the material actually used. Merely citing a bibliographic record does not require every attachment or a digital reproduction of the cited publication. An excerpt or annotation anchored to a particular file normally makes that file a dependency; authors can deliberately include additional research materials. Research navigation relationships remain distinct from dependencies necessary to understand or reconstruct the Work.

The native Work may retain exact-version external material references. Its independent metadata copies do not require duplicating all source bytes into every working package. A complete archival folio gathers the exact records and necessary materials required across the complete Work, history, and all Editions, including dependencies unused by the currently selected Edition. Unrelated libraries, attachments, and related Sources need not be included.

Reconstruction uses enclosed records and material versions without requiring the originating library. Reconnection is optional and deliberate. A missing external file retains its identity and references and is reported as unavailable; matching names or newer material never silently substitute. Missing required dependencies prevent a completeness claim under the archival contract.

## Material versions and removal

Replacing a PDF or other attached material creates a new material version while the bibliographic Source may remain the same. Existing excerpts and annotations retain their original targets; replacement carries no promise of migrating highlights or other attachments. Any reassociation must be deliberate and verified. Retain earlier material versions wherever existing dependencies require them.

Removing a Source from a collection is distinct from destroying records or materials needed by Citations or history. Within the dependency graph Folio controls, retain what existing uses require. Work-local copies survive removal of the originating library record. External files may disappear outside Folio's control; disclose the missing dependency while preserving its references.

## Remaining work

Concrete Source schemas, bibliographic field vocabularies, identity encoding, subset selection, comparison and reconciliation algorithms, material storage, and notification mechanisms remain implementation work. Exact framework divisions and Zotero or BibTeX import/export integrations are not selected. Source Library Document Versions and Time Machine behavior still require investigation.

Issue #8 retains semantic commands and durable history; #13 and #4 retain native package and lifecycle proofs. This contract resolves Source Library and Work-local research ownership without claiming those implementations or proofs complete.
