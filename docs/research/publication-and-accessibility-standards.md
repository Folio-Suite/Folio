<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Publication and accessibility standards relevant to Folio

Research for [Research publication and accessibility standards](https://github.com/ctwelve/Folio/issues/11). Checked 2026-09-03.

## Scope and method

This report identifies standards and platform capabilities that constrain Folio's intended PDF, EPUB, and static-web outputs and the metadata those outputs require. It does not select a conformance target or design Folio's architecture. Sources are standards bodies, registration agencies, the Library of Congress, Apple, and the PDF Association where it distributes ISO texts or formal implementation resources.

The words **MUST**, **SHOULD**, and **MAY** below retain their standards-language meaning only when reporting a cited specification. “Canonical implication” means information that cannot be reliably invented by a renderer; it is an evidence-based input to later design, not an architectural decision.

## Executive findings

1. Accessibility is upstream data. Every target needs the same intellectual semantics: structure and reading order, language, text alternatives, table relationships, navigation, contributor identity, rights, and stable identifiers. PDF/UA expresses these as Tagged PDF; EPUB and the web express them primarily through HTML/XHTML semantics plus metadata. A renderer can encode these facts, but cannot safely infer them from appearance.
2. Accessibility conformance belongs to a particular generated publication. EPUB Accessibility requires a conformance claim and evaluator data tied to the evaluated publication; PDF/UA applies to a PDF file. Such claims therefore cannot be unconditional properties of an abstract manuscript.
3. Identifiers attach at differing levels. DOI permits any granularity but each DOI identifies exactly one referent; ISBN generally distinguishes edition and product format; ORCID identifies a person. Folio must preserve the referent and relationship, not merely an untyped string.
4. A static-web output should be portable semantic HTML with stable URLs/fragment identifiers, separable CSS, and machine-readable publication metadata. That is both the accessible baseline and the cleanest handoff to a larger web-development effort.
5. Preservation is more than choosing PDF/A. The preservation record includes representations/files/bitstreams, fixity and format data, creation or migration events, responsible agents, rights, and relationships. These are partly generated during rendition and partly inherited from authorial provenance.

## PDF, Tagged PDF, and PDF/UA

### Standards baseline

- ISO 32000-2:2020 is the current published core specification for PDF 2.0. ISO describes it as the exchange/viewing representation standard; it does not itself prescribe conversion procedures, validation, rendering UI, or storage media. The published standard is normally paywalled, but the PDF Association provides a sponsor-funded no-cost bundle with ISO-approved errata. An amendment remained in draft as of this review, so it must not be treated as published normative text ([ISO 32000-2 record](https://www.iso.org/standard/75839.html), [sponsored standards and errata](https://pdfa.org/sponsored-standards/)).
- ISO 14289-2:2024 (PDF/UA-2) defines accessible use of Tagged PDF for PDF 2.0. ISO 14289-1:2014 (PDF/UA-1) applies to PDF 1.7. PDF/UA is a technical file-conformance standard, not a complete account of human accessibility and not a recipe for remediating untagged files ([PDF/UA-2 authoritative overview and access](https://pdfa.org/iso-14289-2-pdfua-2/)).
- PDF/A is a separate ISO 19005 family for long-term preservation. PDF/A-4 is based on PDF 2.0. Accessibility and preservation conformance are complementary, not interchangeable; the PDF Association publishes formal guidance on making a file conform to PDF/A and PDF/UA together ([Library of Congress PDF/A family description](https://www.loc.gov/preservation/digital/formats/fdd/fdd000318.shtml), [PDF/A and PDF/UA guidance](https://pdfa.org/resource/conforming-to-both-pdf-a-pdf-ua/)).

### What accessible PDF requires Folio to know

The freely available Matterhorn Protocol enumerates failure conditions for PDF/UA-1 and is useful as a test inventory, but it is subordinate to ISO 14289. Its checks make the upstream requirements concrete: real content must be tagged or marked as an artifact; tags must reflect logical structure and reading order; the document and language changes require language information; text characters require Unicode mapping; figures require alternatives; tables require semantic header/data-cell relationships; headings, lists, notes, links, annotations, and form controls require appropriate structure and accessible names; and navigation and document metadata must be coherent ([Matterhorn Protocol 1.1](https://pdfa.org/resource/the-matterhorn-protocol/)).

Consequently, the source model needs structure independent of page coordinates; explicit reading-order overrides where logical order differs; primary and scoped language; alternate/extended descriptions and decorative status for non-text content; table header scope and associations; link purpose and target identity; and meaningful names for interactive objects. These are Work- or Edition-level facts. Tag-tree objects, marked-content identifiers, artifact bounds, page destinations, embedded-font subsets, and PDF object numbers are Rendition facts.

Fonts and color need careful separation:

- PDF/UA requires characters to be machine interpretable and fonts used for rendering text to satisfy its embedding/mapping rules; accessible text cannot be reduced to an image of glyphs. Folio therefore needs the actual text and language canonically, while font embedding, subsetting, licensing, and substitution are Edition/Theme/Rendition concerns.
- The PDF Association's PDF/UA-2 overview explicitly notes that PDF/UA does **not** address color/contrast or all cognitive-accessibility concerns. Conformance to PDF/UA alone is therefore insufficient evidence that a visually designed PDF is accessible ([PDF/UA-2 overview](https://pdfa.org/iso-14289-2-pdfua-2/)). Color meaning and non-color equivalents originate in content; palette and measured contrast are Theme/Rendition concerns and require an additional policy or evaluation target.

### Metadata and Apple APIs

PDF has document-information metadata and XMP metadata. Apple's Core Graphics can set common author/title/subject/keyword fields, attach an Output Intent, and add an XMP metadata stream. PDFKit exposes basic document attributes and can read/write/search PDF, but Apple's public documentation found in this review does not advertise a PDF/UA authoring or validation API. This is a capability warning, not proof that lower-level construction is impossible ([Core Graphics XMP metadata](https://developer.apple.com/documentation/coregraphics/cgcontext/adddocumentmetadata(_:)), [Core Graphics output intent](https://developer.apple.com/documentation/coregraphics/kcgpdfcontextoutputintent), [PDFKit document attributes](https://developer.apple.com/documentation/pdfkit/pdfdocumentattribute), [PDFKit document](https://developer.apple.com/documentation/pdfkit/pdfdocument)).

The practical validation target must be the final PDF file: structure can be lost or altered during pagination, drawing, font processing, optimization, or post-processing.

## EPUB 3 and EPUB Accessibility

### Current normative baseline and version uncertainty

EPUB 3.3 is a W3C Recommendation. A conforming publication is a ZIP-based EPUB container with a package document, manifest/spine, at least one rendition, a navigation document, and conforming publication resources. Content is based on XHTML and SVG, with reflowable layout the default and fixed layout available ([EPUB 3.3](https://www.w3.org/TR/epub-33/)).

EPUB Accessibility 1.1 is the current W3C Recommendation (17 October 2024). It applies across EPUB versions and defines both discoverability metadata and conformance evaluation. EPUB Accessibility 1.2 was only a Candidate Recommendation Draft at the time of review and must be tracked, not implemented as though final ([EPUB Accessibility 1.1](https://www.w3.org/TR/epub-a11y-11/), [EPUB Accessibility publication series/status](https://www.w3.org/TR/epub-a11y/all/)).

### Structural and metadata requirements

EPUB 3.3 minimally requires package metadata for `dc:identifier`, `dc:title`, `dc:language`, and `dcterms:modified`; it also provides optional creator, contributor, publisher, rights, relation, source, subject, type, roles, collections, and identifier-type metadata. Each content resource must state its own language because it does not inherit package language. The spine gives default reading order, while the navigation document supplies at least the table of contents and can supply page-list and landmark navigation ([EPUB 3.3 package metadata](https://www.w3.org/TR/epub-33/#sec-package-doc-metadata), [EPUB navigation document](https://www.w3.org/TR/epub-33/#sec-nav)).

EPUB Accessibility 1.1 requires discoverability metadata for access modes, accessibility features, and hazards, and recommends an accessibility summary that describes known deficiencies. For certified conformance it requires a precise `dcterms:conformsTo` statement and evaluator information; it uses WCAG plus EPUB-specific requirements and recommends aiming at the latest WCAG 2 Level AA even though its minimum baseline remains WCAG 2.0 Level A ([discoverability](https://www.w3.org/TR/epub-a11y-11/#sec-discoverability), [conformance](https://www.w3.org/TR/epub-a11y-11/#sec-conf-reporting)).

EPUB-specific accessibility requirements include publication-wide evaluation, logical reading order, navigation, accessible page-navigation where supplied, and fallbacks/accessibility for EPUB-specific features. XHTML accessibility depends on retaining semantic elements, image alternatives, table semantics, language, meaningful link text, and media alternatives—not on reproducing print pages.

Canonical implication: Folio needs publication structure, default reading order, navigation landmarks, language, alternatives, page-break/source-page semantics when desired, and accessibility hazards/features. The chosen EPUB layout mode, generated spine/manifest paths, CSS, media fallbacks, `dcterms:modified`, conformance assertion, evaluator/date/report, and any distribution-specific modifications belong to an Edition or Rendition record.

## Static web publications

There is no single current W3C “web publication package” Recommendation equivalent to EPUB 3.3. The dependable standards substrate is the WHATWG HTML Living Standard, CSS, URL semantics, and WCAG. Folio should distinguish that substrate from any optional site generator or deployment convention.

### Normative substrate

- HTML defines document metadata, sections, headings, embedded content, tables, links, language, and element-level semantics. Conforming semantic HTML should be emitted directly; ARIA should supplement semantics where native HTML cannot express the needed role/state, not serve as a replacement vocabulary ([WHATWG HTML semantics](https://html.spec.whatwg.org/multipage/semantics.html)).
- WCAG 2.2 is a W3C Recommendation (and was approved as ISO/IEC 40500:2025). Its testable success criteria govern perceivable alternatives, adaptable structure, distinguishability, keyboard access, navigation, readability, predictability, input assistance, and compatibility. A Folio-generated site must evaluate the complete pages and interactions, not only article markup ([WCAG 2.2](https://www.w3.org/TR/WCAG22/)).
- CSS is designed to separate presentational declarations from the document tree. Cascade layers explicitly support defaults, themes, components, and overrides without rewriting selectors, providing a standards-based mechanism for replaceable/integrated theming ([CSS Cascade Level 5](https://www.w3.org/TR/css-cascade-5/#layering)).

### Requirements for a clean integration surface

The standards do not mandate a particular folder tree or framework. The following are interoperability recommendations derived from them:

- emit valid, readable HTML documents whose headings, sections, lists, notes, figures, tables, citations, and navigation remain intelligible without Folio JavaScript;
- preserve durable element identifiers and predictable relative links so citations, deep links, and external themes do not depend on generated class hashes;
- keep content markup free of layout coordinates and minimize inline style so an external project can replace or layer CSS;
- publish a documented CSS contract—custom properties, named cascade layers, and stable semantic hooks—while treating default CSS as replaceable;
- make progressive enhancement the rule for search, diagrams, notes, and other interactions, with keyboard and non-script fallbacks where applicable;
- expose publication metadata in standard HTML metadata and, where valuable, Schema.org JSON-LD/RDFa. Schema.org defines `Book`/`CreativeWork`, contributors, identifiers, language, rights, citations, and accessibility properties, but it is a community vocabulary rather than a W3C conformance standard ([Schema.org CreativeWork](https://schema.org/CreativeWork), [Schema.org Book](https://schema.org/Book)).

Canonical implication: stable intellectual anchors, hierarchy, language, alternatives, citations, contributor and rights metadata, and relationships must precede generation. Routes, asset fingerprints, generated navigation, CSS bundles, deployment base URLs, search indexes, and final WCAG evaluation are Rendition-specific.

## Publication identifiers and descriptive metadata

### DOI

The DOI Foundation states that a DOI name may identify a digital, physical, or abstract entity at any useful granularity; every DOI identifies exactly one referent and assignment requires metadata sufficient to distinguish that referent. Persistence depends on maintaining the DOI record as location or ownership changes. A DOI can therefore identify a Work, a particular Edition, a chapter, a dataset, or another component—but Folio must record which referent it identifies and must not copy one DOI indiscriminately across changed referents ([DOI Handbook, identifier principles](https://www.doi.org/doi-handbook/html/), especially sections 1.3.1, 3.1, and 4.2.3).

Registration-agency profiles add domain rules. Crossref's book deposit model distinguishes monographs, series, sets, and chapters and accepts book- and chapter-level records. DataCite 4.6 distinguishes resource version, alternate identifiers, and typed relationships such as `IsVersionOf`, `IsNewVersionOf`, `IsPartOf`, `Cites`, and `IsDerivedFrom` ([Crossref books and chapters](https://www.crossref.org/documentation/schema-library/markup-guide-record-types/books-and-chapters/), [DataCite related identifiers](https://datacite-metadata-schema.readthedocs.io/en/4.6/properties/relatedidentifier/), [DataCite version](https://datacite-metadata-schema.readthedocs.io/en/4.6/properties/version/)). The exact metadata obligation depends on the selected registration agency and content type; Folio should not hard-code “DOI metadata” as one universal flat record.

### ISBN

The International ISBN Agency's manual states that a separate ISBN is assigned to each separate monographic publication, edition, or product format issued by a publisher. ISBN is therefore normally Edition/product-format metadata, not the timeless identity of the intellectual Work. A print PDF/product and an EPUB offered separately may need distinct ISBNs under agency rules ([International ISBN User Manual](https://www.isbn-international.org/content/isbn-users-manual)). Registration and display details remain jurisdiction/agency dependent.

### ORCID and other identifiers

ORCID defines an ORCID iD as a persistent, name-independent identifier for a person and a mechanism for trusted connections among researchers, contributions, and affiliations. Folio should attach ORCID to a contributor Agent, alongside the contributor's role and credited name, not use it as a publication identifier ([ORCID explanation](https://support.orcid.org/hc/en-us/articles/360006897334-What-is-an-ORCID-iD-and-how-do-I-use-it)).

Identifiers should always be typed and scoped to an identified entity. At minimum the model needs: scheme/authority, normalized value, display form, target entity, relationship or role, provenance, validation status, and relevant dates. DOI and ORCID resolution require networking, but authoring and preserving the identifier metadata do not.

## Preservation and archival records

The Library of Congress describes PREMIS 3.0 as an implementation-neutral preservation metadata standard with four entities: Objects, Events, Rights, and Agents. It emphasizes recording events that transform objects because those events support provenance and authenticity. PREMIS is not primarily descriptive catalog metadata, and its Rights entity focuses on permissions relevant to preservation ([PREMIS 3.0](https://www.loc.gov/standards/premis/v3/index.html), [PREMIS Data Dictionary](https://www.loc.gov/standards/premis/v3/premis-3-0-final.pdf)).

For Folio, preservation-relevant information falls into two groups:

- Authorial/provenance inputs: stable entity identity, contributor Agents, source relationships, rights and licenses, creation/revision history, original asset formats, declared significant properties, and the intended Edition.
- Rendition/event evidence: exact files and bitstreams, media types and format versions, sizes, cryptographic fixity, creation time, creating application/version, input revision, Theme/profile/configuration, validation results, migrations, and relationships among source and derived objects.

The Library of Congress Recommended Formats Statement prefers EPUB 3 for textual works and identifies PDF/A or high-quality PDF with searchable text, embedded fonts, device-independent color, and tagging as preservation-friendly. These are institutional preferences, not universal conformance law ([Library of Congress Recommended Formats Statement](https://www.loc.gov/preservation/resources/rfs/format-pref-summary.html)). Its format descriptions also report ISO/IEC TS 22424's preservation guidance for EPUB, including METS/PREMIS packaging; those ISO technical specifications are paywalled, so this report does not claim their detailed requirements from the secondary description ([Library of Congress EPUB 3 preservation description](https://www.loc.gov/preservation/digital/formats/fdd/fdd000519.shtml)).

## Allocation matrix for later modeling

This matrix records lifecycle constraints exposed by the standards; it does not prescribe storage classes.

| Information | Must originate before rendering | Publication/Edition-specific | Theme-specific | Final-Rendition evidence |
| --- | --- | --- | --- | --- |
| Semantic hierarchy, headings, lists, notes, citations | Yes | Selection/numbering policy may vary | Visual treatment only | Encoded tags/elements and validation |
| Logical reading order and navigation landmarks | Yes | May select included content | No | PDF tag order; EPUB spine/nav; site nav |
| Language, including local changes | Yes | Publication-wide primary language | Typography may respond | Encoded language and checks |
| Figure meaning, alt/extended description, decorative status | Yes | Edition may choose an equivalent representation | Placement/styling | Encoded alternative and validation |
| Table headers, scopes, relationships, caption/notes | Yes | Edition may simplify or split representation | Presentation | Encoded table structure and validation |
| Contributor Agents, roles, credited names, ORCID | Yes | Credit selection/order may vary | Presentation | Serialized metadata |
| Work/component DOI and relationship | Yes, when assigned | Edition DOI where that is the referent | No | DOI serialized and landing URL checked |
| ISBN | No for abstract Work | Yes, per edition/product format | No | Serialized/displayed value |
| Rights/license/source provenance | Yes | Distribution license can vary | Font/asset license constraints | Embedded notices and preservation record |
| Accessibility features/hazards/summary | Underlying facts originate here | Claim is about selected publication | Theme can introduce/remove barriers | Final metadata, evaluator, date, report |
| Fonts, palette, spacing, page geometry | No | Medium constraints | Yes | Embedded subsets/output intent/contrast results |
| Stable anchors and cross-reference targets | Yes | Route/numbering expression may vary | No | URLs, fragments, destinations |
| Format version, file list, checksums, generator version | No | Target selection | Theme version is an input | Yes |
| PDF/UA, PDF/A, EPUB Accessibility, WCAG conformance claim | No | Target/policy selection | Theme must support target | Only after final evaluation |

## Validation implications, without selecting tooling

- Validate each final artifact, not only the source model. Conformance can be broken downstream.
- Keep normative conformance distinct from lint advice and institutional preference.
- Record validator name/version, standards profile, time, input revision, result, warnings, and any human evaluation. PDF and accessibility include checks that cannot be fully automated.
- Maintain conformance fixtures containing multilingual text, complex scripts, tables, footnotes/endnotes, figures and extended descriptions, math, links, page navigation, lists, annotations, and decorative artifacts.
- Treat external metadata deposits as synchronized records with provenance and status, because Crossref/DataCite/DOI records can be corrected after publication.

## Standards watch list

- EPUB Accessibility 1.2: Candidate Recommendation Draft, not yet a Recommendation at review time.
- ISO 32000-2 amendment and ISO/TS 32005 revision: drafts/current work must not silently replace the published editions.
- WCAG: 2.2 is the stable Recommendation; later work should re-check the current Recommendation when setting a release target.
- WHATWG HTML is deliberately a Living Standard; a web exporter needs a tested compatibility baseline, not an assumed frozen edition.
- Schema.org evolves independently and is not itself an accessibility conformance standard.
- Registration-agency schemas and required fields change; Crossref/DataCite mappings must be versioned adapters.

## Source-access limitations

ISO 32000-2 and ISO 14289 are copyrighted ISO standards. Sponsor-funded copies are available at no cost through the PDF Association but require accepting its delivery mechanism; ISO catalogue pages expose only abstracts/previews. ISO 19005 (PDF/A), ISO/IEC TS 22424 (EPUB preservation), and ISO 26324 (DOI) were not fully available without purchase in this review. Claims about them above are limited to ISO catalogue information, the DOI Foundation handbook, formal PDF Association resources, or Library of Congress format descriptions and are labeled accordingly. W3C/WHATWG specifications, DOI/registration-agency documentation, PREMIS, and Apple API documentation are openly accessible.

## Primary-source index

- [ISO 32000-2:2020 catalogue record](https://www.iso.org/standard/75839.html)
- [PDF Association sponsored ISO standards](https://pdfa.org/sponsored-standards/)
- [ISO 14289-2 / PDF/UA-2](https://pdfa.org/iso-14289-2-pdfua-2/)
- [Matterhorn Protocol 1.1](https://pdfa.org/resource/the-matterhorn-protocol/)
- [EPUB 3.3](https://www.w3.org/TR/epub-33/)
- [EPUB Accessibility 1.1](https://www.w3.org/TR/epub-a11y-11/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [WHATWG HTML Living Standard](https://html.spec.whatwg.org/)
- [DOI Handbook](https://www.doi.org/doi-handbook/html/)
- [Crossref schema documentation](https://www.crossref.org/documentation/schema-library/)
- [DataCite Metadata Schema 4.6](https://datacite-metadata-schema.readthedocs.io/en/4.6/)
- [PREMIS 3.0](https://www.loc.gov/standards/premis/v3/index.html)
- [International ISBN Agency](https://www.isbn-international.org/content/isbn-users-manual)
- [ORCID documentation](https://support.orcid.org/hc/en-us/articles/360006897334-What-is-an-ORCID-iD-and-how-do-I-use-it)
- [Apple PDFKit](https://developer.apple.com/documentation/pdfkit) and [Core Graphics](https://developer.apple.com/documentation/coregraphics)
