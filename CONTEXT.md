# Folio

Folio is a document-centric environment for creating and publishing large, complex works. Its language distinguishes the intellectual work from its authored content, research materials, configured editions, and generated outputs.

## Product

**Suite**:
The complete Folio product: a coordinated collection of desktop applications and shared capabilities that is versioned and distributed as one whole.
_Avoid_: Product family, app bundle

**Profile**:
An exchangeable definition that specializes the semantic structures, validation rules, and available behavior of a Work for a class of documents without creating a separate Work model.
_Avoid_: Format, document type, theme

## The work

**Work**:
The canonical, output-independent intellectual object, including its manuscript, scholarly apparatus, semantic structure, and publication metadata.
_Avoid_: Document, file, project

**folio**:
The complete, durable archival exchange form of a Work, containing the content, history, and dependencies needed to reconstruct it independently of the originating environment. It is distinct from the Folio Suite and from a published Rendition.
_Avoid_: Backup, rendition, working package

**Manuscript**:
The ordered authored content of a Work.
_Avoid_: Document, source file

**Content Unit**:
An independently addressable part of a Manuscript, such as a chapter, section, appendix, sidebar, or note. A Content Unit is a semantic boundary, not necessarily a file.
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
A research object used by or associated with a Work, such as a book, article, archival item, dataset, or interview.
_Avoid_: Reference, attachment

**Citation**:
A relationship from authored content to a Source, including any locator needed to identify the cited evidence.
_Avoid_: Reference, formatted citation text

**Cross-reference**:
A relationship between two internal elements of a Work.
_Avoid_: Link, citation

**Figure**:
A publication object that unites visual content with its caption, attribution, accessibility description, and numbering behavior.
_Avoid_: Image, graphic file

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
