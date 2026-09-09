# ZIP and XML packaging conventions for Folio

Research date: 2026-09-08. This report proposes conventions; it does not change the native format, adopt a conformance specification, or select a ZIP implementation.

## Recommendation

Arrange the native directory package so its reusable assets can retain their paths in an exported folio. Give package metadata a predictable location, separate the private working store from portable content, and make the eventual archive writer consume a prepared directory tree.

The final ZIP operation can then be straightforward. Preparing a **complete folio** is still an export operation: capture a coherent Work revision, serialize semantic XML, collect the exact dependencies, and verify reconstruction. Compressing the native Core Data package alone produces a native backup. It does not produce the independently reconstructible archival form required by [ADR 0005](../adr/0005-native-packages-and-archival-folios.md) and the [archival folio contract](../architecture/archival-folio-contract.md).

Use an ODF/EPUB-inspired container with Folio's own vocabulary, taking OPC's separation of parts and typed relationships as a design lesson. This is a recommendation to borrow useful conventions, **not** to label Folio files as ODF, EPUB, or OPC. Full OPC adoption remains a viable alternative if its tooling becomes valuable enough to justify its additional rules.

## Existing decisions and implementation

The [domain glossary](../../CONTEXT.md) defines a folio as the complete archival exchange form of a Work, including history and dependencies. Native packages may depend on external versioned resources; archival export must capture the required versions and distinguish incomplete exports. XML with namespaces belongs to that exchange representation. [Archival contract](../architecture/archival-folio-contract.md), [semantic model contract](../architecture/semantic-model-contract.md).

The current Write package contains only `Work.sqlite`. Its reader rejects unfamiliar package entries, and its save path constructs and checks an isolated snapshot before handing a package to NSDocument. Consequently, adding even `mimetype` or `META-INF/` is a **deliberate native package format and reader change**, with compatibility tests. This report does not authorize silently dropping new files into existing packages. [Native Work documentation](../../Write/docs/native-work-v1.md).

Research also uses a native directory package (`.frlibrary`), with a closed `Library.sqlite` snapshot and preservation of additional collected files. Its catalog remains an empty shell. Both native document kinds therefore share package semantics, while their domain models and supported contents remain distinct. Neither currently implements the XML container proposed below. [Research shell documentation](../../Research/README.md).

Core Data remains the native authority. Apple documents its store encoding as private, including the SQLite representation; Folio's public XML must describe Folio semantics rather than Apple's database tables. Apple's store guidance is archived documentation, not a newly introduced API contract. [Core Data persistent store guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html).

## What the established containers provide

| Model | Verified convention | Useful lesson for Folio |
| --- | --- | --- |
| OpenDocument 1.4 packages | ZIP entries use Store or Deflate. `META-INF/manifest.xml` inventories content paths and media types and can describe encryption. `mimetype`, when present, is first, uncompressed, and has no local-header extra field; it agrees with the manifest's package media type. The manifest excludes itself and `mimetype`; most other `META-INF/` entries are optional inventory entries. | A recognizable header and explicit inventory work well with a directory package. Specify Folio's own coverage rules rather than inherit ODF's exceptions accidentally. |
| EPUB 3.3 OCF | `META-INF/container.xml` locates the publication package document. `mimetype` is first and contains exactly `application/epub+zip`, without whitespace or BOM, compression, encryption, or ZIP-header extra fields. OCF requires UTF-8 names, permits Store/Deflate and ZIP64, forbids split archives, and uses its own encryption metadata rather than ZIP encryption. | Keep discovery small and independent of the full semantic document. A general “compress folder” operation is not sufficient to guarantee container conformance. |
| OPC, used by OOXML | Parts have names, content types, and byte streams. Relationships connect the package or a part to an internal or external target. ZIP serialization uses `[Content_Types].xml`, package relationships at `_rels/.rels`, and corresponding relationship parts for content parts. | A file inventory and the relationships between files answer different questions. Explicit dependency roles help a reader navigate without understanding every vocabulary. |

Sources: [ODF 1.4 Part 2, §§2.2, 3.2–3.4](https://docs.oasis-open.org/office/OpenDocument/v1.4/os/part2-packages/OpenDocument-v1.4-os-part2-packages.html), [EPUB 3.3 OCF](https://www.w3.org/TR/epub-33/#sec-ocf), [Microsoft parts overview](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/opc/parts-overview), [Microsoft relationships overview](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/opc/relationships-overview), [Microsoft Packaging Team explanation of the ZIP mapping](https://learn.microsoft.com/en-us/archive/msdn-magazine/2007/august/opc-a-new-standard-for-packaging-your-data). Ecma identifies the current OPC part as ECMA-376 Part 2, fifth edition, December 2021; the Microsoft explanations are older first-party documentation. [ECMA-376 publication](https://ecma-international.org/publications-and-standards/standards/ecma-376/).

OPC is a general packaging specification; using it would not require using WordprocessingML as Folio's semantic model. Conversely, copying its filenames alone would not establish OPC conformance. The logical package and its physical mapping have their own requirements. [Microsoft package overview](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/opc/packages-overview).

## Proposed directory layouts

These trees are illustrative. Paths, namespace URIs, extension names, and metadata vocabulary need a later format decision. Do not create empty placeholders for unimplemented capabilities.

For the **next explicitly versioned native package**, retain the existing store filename to avoid an unnecessary move:

```text
Example.fwdoc/
├── mimetype                         native package type marker
├── META-INF/
│   └── package.xml                  package kind/version and store location
├── Work.sqlite                     authoritative private Core Data snapshot
├── assets/                         required assets already held locally
│   └── <stable-storage-key>.png
├── dependencies/                   exact dependency payloads held locally
│   └── <dependency-key>/...
└── previews/                       explicitly derived preview files
```

For the **prepared archival export directory**, whose contents become the ZIP root:

```text
staged-folio/
├── mimetype                         archival type marker
├── META-INF/
│   ├── package.xml                  version, Work entry point, complete inventory
│   └── validation.xml               declared reconstruction checks and results
├── work/
│   ├── work.xml                     Work identity and semantic relationships
│   └── units/
│       └── <content-unit-key>.xml
├── history/                        durable semantic history, when implemented
├── editions/                       every configured Edition
├── assets/                         same keys/paths as native where possible
├── dependencies/                   complete required dependency closure
├── schemas/                        applicable declarative validation resources
└── previews/                       optional declared derived representations
```

Use one small Folio `META-INF/package.xml` initially for both discovery and inventory. Do not copy both ODF's manifest and EPUB's container file merely for resemblance. If later scale requires a separate inventory file, the fixed entry document can reference it. The metadata shape may share a core between Work, Source Library, and other package kinds without making their domain schemas identical.

The native descriptor should identify its package kind, format version, and authoritative store location. If it repeats Work identity or a snapshot generation for inspection, treat those as checked metadata: a mismatch with the store is an error, not permission to choose whichever copy is convenient. It need not maintain an always-current XML rendition of the text.

The archival descriptor should identify the semantic entry point instead. XML becomes authoritative **within that exported artifact**; importing reconstructs a new native store. Exclude Core Data from the normative archival representation. An optional diagnostic/native companion could be designed later, but independent reconstruction must not require it. This preserves the Save/Export distinction already approved in the [archival contract](../architecture/archival-folio-contract.md).

Prefer stable opaque storage keys to author-controlled titles for filenames. Put the original title and filename in metadata. A Content Unit need not be exactly one file; the proposed unit split is an exchange organization choice, not a new constraint on the object model. [Content Unit definition](../../CONTEXT.md).

## Discovery, inventory, and dependencies

Recommended responsibilities for the archival descriptor:

- Package format version, package kind, Work identity, captured revision, and semantic root path.
- For every payload: exact package path, media type, byte length, integrity algorithm and digest, and role such as semantic content, dependency, fallback, or derived preview.
- For every required dependency: stable identity, exact version or revision, enclosed payload, and the capabilities needed for inspection, editing, or reproduction.
- Links between original extension data and fallback representations. A fallback cannot silently replace and discard the original.
- Explicit completeness status and reference to the validation report. A bibliographic URL or provenance link can remain external; a required reconstructive payload cannot be satisfied merely by a URL or local bookmark.

These are Folio recommendations implementing the existing [dependency and independent-reader contract](../architecture/archival-folio-contract.md), not requirements imposed by ZIP.

Keep object identity separate from path, hash, and numbering. A payload hash answers whether bytes match; it does not identify the intellectual object across revisions. Use SHA-256 as a reasonable initial inventory algorithm, with an explicit algorithm field for future evolution. SHA-256 is specified by NIST's Secure Hash Standard. [FIPS 180-4](https://doi.org/10.6028/NIST.FIPS.180-4).

Define hash coverage before implementation. A simple proposal is to hash each enclosed regular file's exact uncompressed bytes, including `mimetype` and the validation report, with `package.xml` itself explicitly exempt from self-hashing. List that exemption in the format. Do not introduce a circular requirement for the manifest to contain its own digest. A separate archive checksum or later signature can cover the final archive; an unsigned manifest cannot authenticate itself against intentional replacement.

Required assets, Profiles, Themes, and Source records must be gathered across the complete Work and all Editions, including required material not used in the current Edition. Do not export entire unrelated Research libraries. Missing, inaccessible, or non-redistributable dependencies require resolution or an explicitly incomplete operation. [Archival contract](../architecture/archival-folio-contract.md), [Source Library contract](../architecture/source-library-contract.md).

## ZIP profile and portable paths

The ZIP specification uses forward-slash relative entry names, without drive letters or leading slashes. Its language-encoding flag identifies UTF-8 names/comments; ZIP64 extends limited-width sizes, counts, and offsets. CRC-32 is part of ZIP's entry integrity mechanism. These facts do not themselves define Folio's package semantics. [PKWARE APPNOTE, §§4.4 and Appendix D](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT).

Recommended Folio writer profile:

- One archive, with no surrounding `Example.fwdoc/` directory. `mimetype` must be the first local entry, stored without compression or extra fields, containing only the agreed ASCII media-type string. Native and archive type markers may differ and must be generated deliberately.
- Write the descriptor near the beginning, then other files in stable path order. Permit Store and Deflate. Store already compressed media when recompression gives no useful reduction.
- Support ZIP64 in both writer and reader; use it when sizes, offsets, or entry counts require it. Test beyond 4 GiB and beyond 65,535 entries. A “large Work” design must not discover those limits at export time.
- Specify UTF-8 entry names explicitly. Prefer generated lowercase ASCII names and short paths for owned payloads; preserve human language in XML metadata and content.
- Never use filenames distinguished only by case or Unicode normalization. Detect collisions before publication and again before extraction. Use no empty directories as semantic markers.
- No executable stub, split archives, ZIP-level encryption, comments carrying essential metadata, or implicit dependence on macOS extended attributes. Encryption and signing need separate format decisions.

These are proposed Folio restrictions. They intentionally choose a smaller surface than arbitrary ZIP while leaving room for large assets.

For package `path` attributes, use one defined representation of the exact entry name. For semantic URI references, specify their base and URI processing separately. Do not percent-decode ZIP filenames opportunistically or treat external URLs as filesystem paths. Relative reference resolution and percent encoding are URI concepts with defined rules. [RFC 3986, §§2 and 5](https://www.rfc-editor.org/rfc/rfc3986).

## XML namespaces, versions, and validation

XML expanded names consist of namespace URI and local name; prefixes are bindings, not semantic identifiers. Namespace URIs need not retrieve schemas. A default namespace applies to unprefixed element names but not unprefixed attributes. [Namespaces in XML 1.0, §§2, 3, 6](https://www.w3.org/TR/xml-names/).

Recommended Folio policy:

- XML 1.0 and UTF-8 for Folio-owned XML. Preserve significant text whitespace; pretty-printing must not insert characters into mixed authored text. XML defines well-formedness, encoding, and whitespace processing separately from application meaning. [XML 1.0](https://www.w3.org/TR/REC-xml/).
- Use publisher-controlled namespace URIs for package and semantic vocabularies. `https://foliosuite.dev/ns/package/1` is an **illustrative candidate**, not an adopted or verified published namespace.
- Keep container version, semantic vocabulary version, and Core Data model version distinct. An application release is not automatically a format version. Use explicit compatibility rules; do not assume every minor-looking number is safe to ignore.
- Supply the agreed DTD for the core, but make namespace-aware validation independent of a particular prefix spelling. DTD declarations do not substitute for validating Folio's complete cross-file graph. The existing contract already permits supplemental mechanisms. [Semantic contract](../architecture/semantic-model-contract.md).
- RELAX NG is a suitable structural validator because its model includes namespace/local-name pairs and ordered content. Schematron is a candidate for assertions across related values; package-wide identity, reference, and dependency checks also need an application validator. Neither choice is settled here. [RELAX NG specification](https://relaxng.org/spec-20011203.html), [Schematron author's explanation](https://schematron.com/document/2760.html).

The archive should carry applicable declarative schemas and their exact identifiers for preservation, while readers select supported processing rules deliberately. Do not execute an enclosed transform, script, plug-in, or remote service to discover how to read basic content. Unsupported required semantics should produce a disclosed capability limitation, and rewriting must preserve unfamiliar data or refuse the operation. [Independent-reader contract](../architecture/archival-folio-contract.md).

MIME type and UTType names are separate registrations. Candidate strings such as `application/vnd.foliosuite.folio+zip` are **provisional examples, not registered types**. RFC 6838 defines media-type registration trees and procedures; RFC 6839 defines the `+zip` suffix. Final file extensions, identifiers, and declarations need a coordinated format change, not a consequence of changing application bundle identifiers. [RFC 6838](https://www.rfc-editor.org/rfc/rfc6838), [RFC 6839, §3.6](https://www.rfc-editor.org/rfc/rfc6839#section-3.6).

## Safe preparation and what “zip up the bundle” means

SQLite WAL can contain committed changes absent from the main database; disconnecting a database from its WAL can lose transactions or corrupt the copied state. The shared-memory file has a different role from the WAL. Neither should be classified as disposable merely by suffix while a store is active. [SQLite WAL, §§2 and 4](https://sqlite.org/wal.html).

Apple's archived QA1809 specifically warns about copying a Core Data main store without its WAL and recommends Core Data migration APIs for backup/restore, with controlled rollback-journal handling as another documented approach. Migration affects coordinator ownership, so it is not a drop-in concurrent file-copy call. [QA1809](https://developer.apple.com/library/archive/qa/qa1809/_index.html), [Core Data store migration behavior](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html).

Recommended export sequence:

1. Capture a defined Work revision through the domain's authoritative persistence interface. Resolve edits versus last-saved state explicitly.
2. Build an isolated staging tree from that revision. Serialize semantic XML and materialize required assets and dependency versions. Reuse immutable asset bytes and relative paths where possible; do not hard-link mutable live files into a supposedly frozen export.
3. Add durable history, Editions, exact declarations, and extension fallbacks according to the export contract. No always-current XML mirror is required during ordinary editing.
4. Validate the staged inventory and reconstruct without the originating environment. Record the actual checks and limitations; a schema pass alone does not establish completeness.
5. Finalize the report and manifest, write the ZIP to a separate destination, then reopen and verify archive integrity and inventory before publishing the result. Failures preserve the previous destination and the native Work.

For a **native backup**, step 2 instead obtains a coherent supported Core Data snapshot together with every package payload needed at that revision. A static, verified package can be compressed for transport, but external native dependencies remain external unless separately gathered. Its backup label must not claim complete folio reconstruction. This distinction follows the [native/archival contract](../architecture/archival-folio-contract.md).

Recommended exclusions from archival staging: the private SQLite store and operational companions; caches, indexes, lock files, recovery scratch, window state, security-scoped bookmarks, `.DS_Store`, AppleDouble metadata, and staging output. This is an **export selection policy**, not a cleanup command for live packages. Preserve meaningful metadata in declared portable content before excluding a platform-specific representation. Security-scoped bookmarks are an access mechanism, not enclosed dependency payloads. [Apple sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox).

## Reader requirements and repeatable output

Proposed minimum reader requirements are directly relevant to a container that writes onto disk:

- Reject duplicate names, collisions, absolute paths, traversal components, backslashes, links, special files, and local-header/central-directory disagreements. Extract only into a fresh controlled directory and never follow pre-existing symlinks. Libarchive exposes explicit protections for absolute paths, `..`, and symlink redirection; its documented defaults show why selecting a library is not sufficient by itself. [Libarchive extraction API](https://raw.githubusercontent.com/libarchive/libarchive/master/libarchive/archive_write_disk.3).
- Bound entry count, path depth, expanded bytes, individual XML size/depth, and processing time. Enforce actual streamed output limits as well as header estimates. Treat nested archives as opaque assets unless explicitly opened under their own limits. Choose product limits through large-Work tests; do not declare a small arbitrary archive ceiling merely for convenience.
- Parse XML without arbitrary network or local external-entity resolution. If core DTD validation is enabled, use an allowlisted local resolver with expansion limits. An XML parser's external-entity option is an explicit capability to control. [Foundation XMLParser](https://developer.apple.com/documentation/foundation/xmlparser/shouldresolveexternalentities).
- Verify inventory sizes and hashes before trusting a payload. Distinguish byte integrity, semantic validity, supported capabilities, and successful reconstruction in results. Never auto-install or execute an archive's content.

For repeatable output, sort inventory and ZIP entries, use deterministic serialization, normalize archive timestamps/attributes, and avoid volatile build-machine metadata. Keep authored timestamps as semantic data. This is a proposed build policy; byte-identical output also requires controlling compressor behavior. Compare uncompressed payload hashes when different compressors legitimately produce different ZIP bytes.

Do not equate pretty XML with canonical XML. W3C canonicalization specifies a particular byte representation for applicable XML information, not a general proof that differently structured documents have the same meaning. Exact payload-byte hashes need no canonicalization; semantic-equivalence hashes or XML signatures require an explicitly chosen algorithm later. [Canonical XML 1.1](https://www.w3.org/TR/xml-c14n11/).

## Adopt now; defer deliberately

**Next native-format slice:** agree the small descriptor and common asset-path rules; add them through a versioned package writer/reader change; preserve Core Data authority and the existing coherent snapshot boundary. Test old-package handling, unknown entries, descriptor/store mismatches, and path collisions. Do not promise backward writing compatibility or ship placeholder XML content.

**First archival-export slice:** define the semantic XML subset and completeness levels, serialize from a captured revision, gather dependencies, generate the inventory/report, and prove isolated reconstruction. Include ZIP64, extraction, missing-dependency, and interrupted-export cases. The current limited editor cannot claim the full durable-history and reproduction contract merely because it can serialize its text.

**Defer:** complete namespace/version governance, MIME registration, signatures/encryption, a universally shared manifest for every package kind, optimized incremental exports, semantic XML canonicalization, and byte-for-byte reproducible ZIPs. These can be specified without changing the basic common-directory approach.

At the present library boundary, common path validation, staged package access, inventories, and eventual ZIP mechanics fit `FKPackageSupport`; semantic XML mechanisms fit `FKXMLSupport`; Write's semantic serialization and coherent Work snapshots remain owned through WriteKit and its internal libraries. This is an allocation recommendation based on the [current library layout](../architecture/current-library-layout.md), not an additional refactor in this research pass.
