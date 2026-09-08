# Folio

Folio is a document-centric environment for creating and publishing large, complex works. Its language distinguishes the intellectual work from its authored content, research materials, configured editions, and generated outputs.

## Product

**Suite**:
The complete Folio product: a coordinated collection of desktop applications and shared capabilities that is versioned and distributed as one whole.
_Avoid_: Product family, app bundle

**Profile**:
The exchangeable governing definition that specializes the semantic structures, validation rules, and available behavior of a Work for a class of documents. One Profile governs a Work and may compose semantic vocabularies without creating a separate Work model.
_Avoid_: Format, document type, theme

**Semantic Vocabulary**:
A named collection of semantic types and contracts describing related kinds of content, properties, and relationships within a Work.
_Avoid_: Application, Profile, serialization format

## The work

**Work**:
The canonical, output-independent intellectual object, including its Manuscript, unplaced authored material, scholarly apparatus, semantic structure, and publication metadata.
_Avoid_: Document, file, project

**folio**:
The complete, durable archival exchange form of a Work, containing the content, history, and dependencies needed to reconstruct it independently of the originating environment. It is distinct from the Folio Suite and from a published Rendition.
_Avoid_: Backup, rendition, working package

**Manuscript**:
The primary assembled, ordered text of a Work, arranged from its Content Units. Authored material may belong to the Work without being placed in the Manuscript.
_Avoid_: Document, source file

**Content Unit**:
An independently identifiable unit of authored content within a Work, such as a chapter, section, appendix, sidebar, or Note, whether placed in the Manuscript or currently unplaced. A Content Unit is a semantic boundary, not necessarily a file.
_Avoid_: File, page, chunk

**Assembly**:
An intellectual structure that arranges independently identified Works without absorbing their identities, such as a collected volume or linked corpus.
_Avoid_: Master document, collection, multi-file Work

**Work Session**:
The active, authoritative state of an open Work through which multiple Suite applications may read and request changes. Its authority is independent of any application's presentation or lifetime.
_Avoid_: Broker, working document

## Research and relations

**Source Library**:
An author's reusable, versioned collection of Sources, independent of any one Work. An author may maintain multiple Source Libraries for different topics or purposes.
_Avoid_: Bibliography, references folder

**Source**:
An independently citable research object, such as a particular book edition, article, archival item, dataset, or interview. Related editions and translations retain distinct identities.
_Avoid_: Reference, attachment

**Source Record**:
A description of a Source owned by a Source Library or Work, including bibliographic information and associated research material. Distinct records may describe the same Source while retaining independent revisions and provenance.
_Avoid_: Source identity, bibliography entry

**Citation**:
A relationship from authored content to one or more Sources, with each individual Source reference retaining its locator and qualifying text. Multiple Source references may form one Citation occurrence.
_Avoid_: Reference, formatted citation text

**Cross-reference**:
A relationship between two internal elements of a Work.
_Avoid_: Link, citation

**Figure**:
A publication object that unites visual content with its caption, attribution, accessibility description, and numbering behavior.
_Avoid_: Image, graphic file

**Note**:
Authored content attached to other content in a Work, with its semantic role distinct from its placement at a foot, end, or margin.
_Avoid_: Editorial comment, annotation

## Editorial material

**Editorial Annotation**:
Editorial material, such as a Comment or Proposed Revision, related to authored content without belonging to its textual structure.
_Avoid_: Note, footnote, endnote, marginalia

**Comment**:
An editorial observation with explicit targets, such as text ranges or identified objects, and potentially related replies.
_Avoid_: Note, authored text

**Proposed Revision**:
A tracked proposal to insert, delete, replace, or structurally change authored content, distinguishable from approved wording and durable editing history.
_Avoid_: Document Version, accepted wording, history entry

## Publication

**Theme**:
An exchangeable presentation definition that maps semantic structures to medium-specific composition. A Profile may recommend or include Themes, but does not require them.
_Avoid_: Profile, document type

**Edition**:
A configured expression of a Work for a particular audience, purpose, or publication context.
_Avoid_: Format, export

**Rendition**:
A concrete output generated from an Edition, such as a PDF, EPUB, or static website.
_Avoid_: Edition, conversion

**Numbering Series**:
An independently identified sequence of publication objects with membership, ordering, restart, and marking rules. Its resolved ordinals and marks belong to a particular composition.
_Avoid_: Object identity, semantic kind, placement

**Mark**:
The reader-facing sign identifying a publication object, such as a formatted number, letter, symbol, or explicit label, distinct from that object's identity and ordinal.
_Avoid_: Identifier, ordinal
