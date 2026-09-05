# Native packages and archival folios

Approved in the follow-up design interview, Q26–Q35. See [ADR 0005](../adr/0005-native-packages-and-archival-folios.md). This decision refocuses existing storage tickets without declaring their implementation and lifecycle proofs complete.

## Native working form

Native storage uses on-disk packages. Define separate package types for Works, libraries, Profiles, and other concepts as needed; do not prematurely impose one package schema on every concept. Internal working-store technology remains open.

A native Work may reference assets, Profiles, Themes, settings, and research resources outside its package. Record the exact versions in use, detect newer versions, and adopt updates deliberately. Libraries support versioned objects, and authors may maintain multiple libraries for different topics or purposes. Investigate and prove native Document Versions and Time Machine integration rather than assuming they provide semantic object history automatically.

Save and Auto Save persist native state. Export produces a folio separately. Helper Quit preserves state for resumption and does not implicitly request archive export. Native document behavior and the approved Work Session safety guarantees remain in force.

## Archival completeness

A folio is the object preserved for posterity: a durable, fully serialized archive that can reconstruct the Work from zero using compatible software, including the Folio Suite. Include the complete Work and durable history, all its Editions, and exact dependencies required to inspect, edit, and reproduce them. Capture required Profiles, Themes, assets, settings, referenced library records, and necessary research materials, including dependencies unused by the current Edition. Entire unrelated libraries are not required.

Extensively document and specify the format so anyone can implement compatible software. Prefer highly standardized, purpose-appropriate internal formats. PDF/A and PDF/X were examples of the desired standards discipline, not a blanket choice for all content. Exact format versions, conformance requirements, XML schemas, and archive encoding remain to be specified; ZIP + XML is prior context, not a substitute for that specification.

A complete export verifies its dependency inventory, exact versions, integrity hashes, and required fallback representations, then verifies reconstruction in an isolated context without the originating libraries, installed extensions, or original file locations. Include a machine-readable manifest and validation report. Define precise verification coverage as part of the later conformance specification.

If a dependency is missing, inaccessible, or cannot be redistributed, explain the unresolved requirement and allow resolution or replacement. Any explicitly reduced, redacted, or incomplete export is a separately identified operation and must not be represented as a complete folio.

## Independent readers and extension preservation

Define reader capabilities explicitly: inspection/extraction, reconstruction/editing, and Rendition reproduction. A reader detects unsupported requirements, discloses limitations, and preserves unfamiliar content when rewriting. It cannot claim complete reconstruction after dropping meaning.

Basic reconstruction does not require an original plug-in, execution of an embedded script, or an external service. Preserve declarative semantics and original structured extension data alongside durable, accurate standard representations, relevant text, accessibility information, and relationships. An unsupported object may be presented read-only while its original data remains available to a capable editor.

Identify extensions using publisher-qualified package identifiers, versions, and relevant schema identifiers. Specialized editing or reproduction may require declared capabilities; the absence of those capabilities must not make the underlying intellectual content inaccessible.

## Reconstruction

Opening a folio reconstructs a native package using its enclosed dependency versions as authoritative. No prior library setup is required. Reconnection to existing libraries is optional and deliberate; matching names or newer available versions never silently substitute content. Preserve provenance where appropriate. The original folio remains unchanged as the archival artifact.

## Remaining work

Issue #13 proves native package saving, recovery, Document Versions, consistent snapshots, external versioned dependencies, complete export, and isolated reconstruction with representative large assets and a File Provider location. Preserve cloud, indexing, sandbox, migration, and scale probes. Issue #4 settles the detailed authority and lifecycle contract from that evidence. The native-package choice is settled.

Issue #6 must account for independently specified semantics, preservation of unknown structures, capability declarations, and extension fallbacks. Issue #7 retains Source Library ownership and reconciliation design; issue #8 retains durable history design. Their existing scopes remain intact.
