<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Large, complex document systems: landscape and Folio opportunity

_Research date: 2026-09-03_

## Question

What professional software sits between general-purpose word processors, TeX-family publishing toolchains, and manually intensive desktop-publishing tools for producing large, heavily researched books? In particular, which systems combine mostly automatic, high-quality book typography with figures, tables, cross-references, notes, citations, appendices, and indexes—and is there a credible opening for Folio?

## Executive conclusion

There is a credible product gap, but it is narrower and more interesting than “nothing like this exists.” Several products cover most of the requested mechanics. None of the serious current comparators combines all four of these qualities:

1. a humane, modern writing and research environment for an individual scholar or small editorial team;
2. an integrated, first-class source/citation/annotation model rather than a plug-in or post-processing seam;
3. deterministic, largely automatic, genuinely book-quality composition with controlled escape hatches; and
4. a portable, inspectable, durable document model that does not require TeX expertise or an enterprise XML/CCMS program.

The nearest precedents are **Adobe FrameMaker** for long-document composition, **Nota Bene** for integrated scholarly research and writing, **LyX** for structure-first graphical authoring over LaTeX, and **Paligo / Oxygen / Arbortext / MadCap Flare** for structured, automated publishing. Each validates part of the idea; each also leaves an important opening.

The strongest Folio thesis is therefore not “replace Word, LaTeX, and InDesign.” It is:

> Build the integrated scholarly long-document system that FrameMaker never became cross-platform, Nota Bene never modernized into, LyX cannot become without ceasing to be a LaTeX front end, and enterprise structured-authoring systems do not try to be.

## The actual market topology

| Category | Representative products | Dominant interaction model | What it optimizes | Structural mismatch with the proposed need |
|---|---|---|---|---|
| Long-document processors | Adobe FrameMaker; historically Ventura Publisher and Interleaf | Paginated editor plus styles/book assembly; optional XML structure | Stable manuals and books with automated generated matter | Legacy/enterprise orientation; weakly integrated scholarly research; FrameMaker is Windows-only |
| Scholarly workstation | Nota Bene | Word-processor-like editor integrated with bibliography and textbase tools | Humanities research, notes, citations, multilingual scholarly manuscripts | Proprietary, visually dated ecosystem; typography/composition is less programmable and less publication-engine-like |
| Graphical TeX front end | LyX | WYSIWYM structured editor | Making LaTeX accessible without writing most markup | Still inherits the TeX distribution, classes, packages, diagnostics, and customization model |
| XML structured authoring / CCMS | Arbortext, Oxygen XML Author, Paligo | Schema-constrained topic/component authoring and transformation pipelines | Reuse, variants, compliance, translation, multichannel technical publishing | Enterprise setup and vocabulary; book-as-research-argument is secondary; typography often requires stylesheet/pipeline engineering |
| Help-authoring / single-source publishing | MadCap Flare | Topic authoring, project tree, TOC/target, CSS/page-layout configuration | Documentation sites plus PDF/Word deliverables | Technical-documentation mental model; no native scholarly research system |
| Lightweight code-first publishing | Typst, Quarto/Pandoc, SILE | Text markup + templates + compiler | Reproducible, automated output with version-control-friendly sources | Source/toolchain interaction; fragmented research workflow; book typography and edge cases can require programming |
| Book writing/formatting | Scrivener, Vellum, Atticus | Binder/manuscript editor or theme-driven formatter | Drafting and attractive trade-book/e-book output | Limited semantic apparatus and scholarly automation; usually hands off citation processing or advanced production |
| Manual page layout | InDesign, Affinity Publisher, QuarkXPress | Direct manipulation of pages, frames, masters, and styles | Maximum art direction and production control | Layout remains an editorial production activity; semantic research data is external |

## Serious comparators

### Adobe FrameMaker: the clearest direct predecessor

FrameMaker is the closest surviving answer to “a book processor, not a word processor or page-layout canvas.” Its book files reference component documents, coordinate volume/chapter/page/paragraph numbering, and incorporate generated TOCs, lists of figures/tables, and indexes ([Adobe, Books and long documents](https://help.adobe.com/en_US/framemaker/using/using-framemaker/user-guide/frm_books_bk-books-and-long-documents.html)). FrameMaker can generate lists and indexes from paragraph text and markers, including diagnostics such as unresolved cross-references ([Adobe, TOCs and generated lists](https://help.adobe.com/en_US/framemaker/using/using-framemaker/user-guide/topic_toc-and-lists.html)).

It also has a genuinely structured mode: an Element Definition Document and template define an authoring environment, and FrameMaker can represent cross-references, equations, tables, graphics, markers, and footnotes as structured objects while producing print, PDF, HTML, XML, or SGML ([Adobe, structured documents overview](https://helpx.adobe.com/framemaker/kb/overview-structured-documents-sgml-xml.html)). This is strong evidence that structure-aware, mostly automatic book composition is a coherent product category, not a fantasy.

Its mismatch is equally revealing. Current FrameMaker is a locally installed, activation-dependent **Windows 11-only** application ([Adobe, FrameMaker system requirements](https://helpx.adobe.com/uk/framemaker/help/fm_system_requirements.html)). Its center of gravity is technical communication and XML workflows, not a scholar's continuous loop among sources, annotations, argument, citations, prose, and publication. Citation management is not the deep center of the product. Its structured-authoring power also asks users or organizations to understand templates, EDDs, schemas, and publishing configuration.

**Lesson for Folio:** FrameMaker validates the long-document engine and book-assembly model. Folio's opportunity is to pair that seriousness with a modern research-native information architecture and a gentler progressive-disclosure interface.

### Nota Bene: the closest research-native predecessor

Nota Bene is the most important comparator that is easy to miss. It is explicitly an integrated academic workstation: the Nota Bene processor, **Ibidem** bibliographic database, **Orbis** search/retrieval system, and a general database tool are sold as one research-and-writing suite ([Nota Bene, products](https://www.notabene.com/products.html)).

Its scholarly feature set maps strikingly well to the proposed problem. Official documentation describes up to three independent footnote/endnote series, automatic bi-directional cross-references to chapter/section/page/footnote numbers, generated indexes, academic style frameworks, and Ibidem-managed in-text, footnote, endnote, bibliography, and reference-list formatting ([Nota Bene, specialized academic features](https://www.notabene.com/help/specialized_academic_features.htm)). Orbis searches large collections of the author's own material at paragraph or other granularities and can insert retrieved text; when notes are linked to Ibidem records, retrieval can insert the corresponding citation ([Nota Bene, Orbis](https://nb.notabene.com/orbis/)). Chapters can be combined into manuscripts, and the product explicitly advertises outlines, indexes, cross-references, and long-form footnoting ([Nota Bene, current product overview](https://nb.notabene.com/)).

This means Folio cannot credibly claim that integrated scholarly writing, retrieval, bibliography, and long-document mechanics have never been combined. They have. The opening is that Nota Bene embodies this model in a proprietary workstation descended from traditional word-processing interaction and page formatting, rather than a modern semantic document system with a deeply programmable deterministic composition engine, collaborative architecture, and broadly portable deployment.

**Lesson for Folio:** treat Nota Bene as a conceptual ancestor and a feature-floor for humanities scholarship, especially citation-note interaction, multiple note streams, source-linked notes, textbase retrieval, indexing, and multilingual work.

### LyX: the closest interaction philosophy, but still LaTeX

LyX explicitly describes itself as WYSIWYM—writing based on document structure rather than appearance—and combines a graphical interface with LaTeX ([LyX, home](https://www.lyx.org/Home)). It supports labels and cross-references, indexes, BibTeX bibliographies, numbered structure, TOCs, lists of figures/tables, an outliner, semantic character styles, floating figures/tables, captions, branches, change tracking, and configurable converters. It runs on Linux, Windows, and macOS ([LyX, features](https://www.lyx.org/Features)).

It therefore addresses much of the proposed interaction problem. But it does so by exposing and packaging the LaTeX ecosystem: its own feature list emphasizes access to all LaTeX functionality, insertion of raw LaTeX, text classes, modules, and converters. The output quality is inherited strength; the distribution, package, class, debugging, and deep-customization experience remains substantially TeX-shaped.

**Lesson for Folio:** WYSIWYM is a proven middle path. The opportunity is a native semantic model and composition engine whose abstractions stop at a deliberately designed boundary instead of opening into arbitrary TeX.

### XML and component-content systems: powerful, but aimed elsewhere

#### PTC Arbortext

Arbortext combines schema-valid XML/SGML authoring, reusable components, stylesheet design, advanced layouts, and an automated Publishing Engine for PDF, HTML, web, and interactive output. It supports DITA, S1000D, Schematron, third-party plug-ins, and customization in C/C++, Java, JavaScript, JScript, and VBScript ([PTC, Arbortext Editor](https://www.ptc.com/en/products/arbortext/editor)). Its suite integrates content with Windchill, CAD, bills of materials, translation, and formal workflow ([PTC, Arbortext overview](https://www.ptc.com/en/products/arbortext)).

That is formidable automation and determinism, especially for regulated technical publications. It is also an enterprise product-development ecosystem. The source unit is a reusable, governed component tied to product information—not primarily a scholar's claim, quotation, archival source, note, or evolving chapter argument.

#### Oxygen XML Author and DITA

Oxygen provides a friendlier authoring face over DITA/XML and built-in transformations from DITA maps to PDF, WebHelp, ODF, XHTML, EPUB, and other formats ([Oxygen, DITA map framework](https://www.oxygenxml.com/doc/versions/28.1/ug-editor/topics/author-dita-map-doc-type.html)). DITA `bookmap` directly models frontmatter, parts, chapters, appendices, backmatter, generated TOC, index, and book metadata ([Oxygen, creating a bookmap](https://www.oxygenxml.com/doc/versions/28.1/ug-author/topics/eppo-create-book-map.html); [OASIS DITA 1.3 bookmap specification, hosted by Oxygen](https://www.oxygenxml.com/dita/1.3/specs/archSpec/technicalContent/dita-spec-intro-bookmap.html)). DITA even has a `bibliolist` hook, but the specification leaves actual generation to an external processor ([OASIS DITA `bibliolist`](https://www.oxygenxml.com/dita/1.3/specs/langRef/technicalContent/bibliolist.html)).

Oxygen's CSS-based PDF publishing makes the tradeoff plain: it is automatic and customizable, but serious output work involves CSS, XPath, XML transformations, and publishing-engine configuration. It is excellent infrastructure for semantic technical content, not an integrated scholarly knowledge-and-book environment.

#### Paligo

Paligo is a cloud CCMS. Content is authored as reusable, versioned, translated, reviewed, metadata-tagged components and published across channels ([Paligo, product overview](https://paligo.net/product-overview/)). Its PDF layout system includes configuration for document geometry, tables and table footnotes, glossaries, indexes, and bibliographies ([Paligo, PDF Layout Editor](https://docs.paligo.net/en/pdf-layout-editor-options.html)); it supports bibliography styles for PDF and HTML layouts ([Paligo, bibliography style](https://docs.paligo.net/en/choose-your-bibliography-style.html)).

Paligo supplies collaboration, governance, reuse, and cloud deployment that desktop predecessors lack. But it is priced, packaged, and conceptually organized as enterprise component-content infrastructure. “Bibliography” is a publishing feature, not an integrated research library and evidence graph.

#### MadCap Flare

Flare can produce serious print output. A PDF/Word target may include images, tables, reusable snippets, variables, index markers, cross-references, footnotes, an endnotes proxy, lists of figures/tables, chapter breaks, and autonumbering; page layouts control page size, margins, headers, footers, and page numbers ([MadCap, Print-Based Output](https://help.madcapsoftware.com/flare2025r2/Content/Flare/Print-Based-Output/Print-Based-Output.htm)). Cross-reference styles can turn online links into page-number references in print ([MadCap, Cross-References](https://help.madcapsoftware.com/flare2025r2/Content/Flare/Step2-Authoring/Links/Cross-References/Cross-References.htm)).

Its model remains topic/project/TOC/target/CSS: ideal for single-sourced product documentation, less natural for a 500-page monographic argument and its research corpus. Citation-library integration is not a foundational capability.

**Collective lesson:** enterprise structured publishing proves that deterministic multichannel automation, reusable semantic components, and very large publications are feasible. Folio should borrow the architecture without importing the enterprise ontology, schema ceremony, procurement model, or stylesheet-engineering burden.

### Code-first successors: Typst, Quarto, and SILE

These systems reduce some TeX pain but do not occupy the proposed end-user product position.

- **Typst** offers modern markup, programmable layout, automatic footnotes, bibliography/citation handling, references, figures, tables, page configuration, and fast PDF production ([Typst footnotes](https://typst.app/docs/reference/model/footnote/); [Typst reference](https://www.typst.app/docs/reference/); [Typst page setup](https://www.typst.app/docs/guides/page-setup/)). It is the strongest evidence for a cleaner post-TeX composition language, but its primary interaction remains source plus compiler/preview rather than an integrated research workstation.
- **Quarto** models multi-chapter books, generates a consolidated PDF/Word document or website, resolves cross-chapter references to figures, tables, equations, sections, listings, theorems, and proofs, and creates a generated bibliography from project sources ([Quarto, book cross-references](https://quarto.org/docs/books/book-crossrefs.html); [Quarto, book structure](https://quarto.org/docs/books/book-structure)). It uses CSL bibliographies and ultimately delegates PDF behavior to selectable engines, commonly LaTeX ([Quarto, PDF options](https://quarto.org/docs/reference/formats/pdf.html)). This is excellent reproducible publishing, but it remains a file/toolchain workflow.
- **SILE** is a programmable typesetting engine with book classes and sophisticated layout ambitions, but its official manual has described bibliography/indexing support as limited or experimental—for example, its BibTeX package could format citations and individual references but not full bibliography lists in the documented release ([The SILE Book 0.14.13](https://sile-typesetter.org/manual/sile-0.14.13.pdf)). It is an engine candidate or source of ideas, not the complete product.

**Lesson for Folio:** these projects demonstrate that a new composition engine is plausible. They do not solve research capture, source-reading, long-form conceptual organization, semantic editing, and production as one system.

### Drafting and automatic book formatters

**Scrivener** is excellent at decomposing manuscripts into manageable units, maintaining research beside a draft, and compiling those units into delivery formats. Its official manual exposes extensive compile transforms and footnote/comment handling ([Literature & Latte, Scrivener 3 manual](https://www.literatureandlatte.com/docs/Scrivener_Manual-Win.pdf)). But bibliography processing is typically external; compilation is chiefly a manuscript transformation and handoff, not a high-end deterministic book-composition and scholarly-data engine.

**Atticus** combines browser/PWA-based writing with templates, theme customization, print/e-book previews, print typography controls, and PDF/e-book export across desktop operating systems ([Atticus, product](https://www.atticus.io/); [Atticus, Quick Start](https://www.atticus.io/quick-start-guide/)). It supports footnotes and end-of-chapter or end-of-book endnotes ([Atticus help, notes](https://intercom.help/atticus-5877e36564df/en/articles/12684371-does-atticus-support-footnotes-or-endnotes)). This validates demand for “choose a good book design and let the system compose it.” Its public feature model does not approach scholarly cross-reference, citation-library, complex table/figure, apparatus, and indexing requirements.

**Vellum** similarly represents highly constrained, attractive automatic trade-book/e-book formatting, with a macOS-centered product and fixed output feature envelope ([Vellum, technical specifications](https://vellum.pub/specs/)). These tools succeed precisely because they sharply limit layout and semantic complexity.

**Lesson for Folio:** smart defaults and constraint can make automatic composition delightful. Folio needs a principled way to retain that ease while progressively revealing the machinery needed for complex scholarly books.

### InDesign and the boundary of manual DTP

InDesign actually contains much of the needed apparatus: footnotes/endnotes, image captions, cross-references, indexes, books, and PDF export ([Adobe, InDesign help contents](https://helpx.adobe.com/uk/indesign/desktop.html)). It can build hierarchical index entries from embedded markers across book documents ([Adobe, index entries](https://helpx.adobe.com/uk/indesign/desktop/indexes-and-references/create-an-index/create-index-entries.html)), and synchronize cross-reference formats across a book ([Adobe, cross-references](https://helpx-origin-ew1.aws116.adobeitc.com/nz/indesign/using/cross-references.html)).

But the governing abstraction is still pages, frames, styles, and production panels. Even some seemingly book-global mechanics expose document/story boundaries: Adobe documents that endnote numbering does not continue across documents in a book ([Adobe, endnotes](https://helpx.adobe.com/nz/indesign/using/endnotes.html)). Citation data and research remain external.

**PageMaker is historically relevant mainly as a category marker, not as Folio's true ancestor.** Its conceptual lineage is page layout: arrange publication pages more conveniently than paste-up. The more relevant lineage is FrameMaker / Ventura / Interleaf: systems that treated a long publication as structured flowing content with generated matter and repeatable composition. Folio should resist nostalgia for PageMaker's canvas and recover the deeper “document processor” idea.

## Citation integration is a revealing fault line

Zotero's own documentation illustrates why “supergluing Zotero to Word” feels incomplete. Its Word/LibreOffice/Google Docs plug-ins insert dynamic citations and update bibliographies, but the host word processor controls footnote/endnote appearance; citations live through host-specific fields or bookmarks ([Zotero, word-processor plug-in usage](https://www.zotero.org/support/word_processor_plugin_usage)). In an RTF workflow, Zotero scans textual placeholders after writing, asks the user to resolve ambiguous matches, and requires a full word processor to render note-based output correctly ([Zotero, RTF Scan](https://www.zotero.org/support/rtf_scan)).

This is functional integration at the output-text boundary, not one shared data model. A Folio source reference could instead remain a typed, queryable relation among a claim or passage, a source record, a locator, captured evidence, annotations, citation rendering, and the eventual note/bibliography. That would improve integrity and enable capabilities that are hard when the citation manager and document processor merely exchange fields or strings.

## Is the gap commercially and technically credible?

### Yes, on product coherence

The surveyed products distribute the desired capabilities across incompatible centers of gravity:

- FrameMaker has the book engine but not the scholarly workstation or modern cross-platform experience.
- Nota Bene has the scholarly workstation but not a modern semantic/composition/platform story.
- LyX has the right structure-first philosophy but deliberately remains LaTeX.
- XML/CCMS products have robust structure, reuse, governance, and publishing but impose enterprise technical-documentation concepts and setup.
- Typst/Quarto have cleaner reproducibility but are source/toolchain products.
- Scrivener/Atticus/Vellum have humane writing or automatic formatting but lack the full scholarly and document-engine apparatus.
- InDesign has typographic power but treats layout as production work.

That is a real white space: **research-native structured authoring plus automatic professional book composition for individual experts and small teams**.

### Qualified yes, on business opportunity

The gap may persist partly because the audience is demanding but smaller than the markets for office suites, enterprise documentation, and trade self-publishing. A successful Folio likely cannot begin as “all complex documents.” It needs a sharp initial constituency whose pain pays for depth—plausibly humanities/social-science monographs, legal scholarship, policy/standards books, or another footnote-heavy domain—and a narrow set of publication contracts it fulfills extremely well.

The competition is also a workflow assembled from good-enough pieces: Scrivener or Word + Zotero + publisher templates + copyeditor + InDesign, or Markdown/Quarto/LyX + bibliography files + a technically capable author. Folio must make the integrated model visibly safer, calmer, and more powerful than that chain, not merely put all its panels in one window.

## Product implications for Folio

1. **Make the semantic manuscript—not the page or source markup—the primary artifact.** Pages are projections; layout code is an implementation detail; source records and citations are durable objects.
2. **Treat a large work as a graph with a strong ordered spine.** Chapters and appendices need simple human-visible order, while claims, sources, notes, figures, tables, cross-references, variants, and index concepts form typed relations.
3. **Integrate research before citation.** Capture sources, locators, excerpts, annotations, claims, and provenance; citation rendering is a view over those objects.
4. **Use progressive disclosure for composition.** A template should produce a beautiful, stable book automatically. Experts then adjust named policies and constraints—not drag 500 pages into place or edit arbitrary low-level code.
5. **Make determinism inspectable.** Every generated number, moved float, page break, note placement, index entry, and bibliography item should be explainable and traceable to a rule and source object.
6. **Separate semantic validity from compositional diagnostics.** “This reference has no target,” “this source lacks required metadata,” and “this float could not be placed under current constraints” are different classes of problem.
7. **Design escape hatches as bounded overrides.** Exceptional pages and figures are inevitable, but overrides should be local, named, reviewable, and detectable when upstream edits invalidate them.
8. **Use open interchange at the boundaries.** CSL JSON/BibLaTeX/RIS for bibliographic exchange, accessible PDF for fixed output, EPUB/HTML where appropriate, and a documented archival source form reduce lock-in even if Folio's richer internal model is novel.
9. **Do not lead with enterprise reuse.** Variants, components, collaboration, and workflow matter, but the initial experience should feel like making one great book, not administering a content supply chain.

## A useful positioning test

Folio should be able to take a deeply researched 500-page manuscript and truthfully offer:

> Write and organize at the level of chapters, arguments, sources, evidence, notes, figures, tables, and references. Choose a publication design. Folio continuously composes the book, explains every unresolved issue, and gives precise control where the automatic result is not enough—without making pages, XML, or typesetting code your daily workspace.

If it can do that, it is not merely another word processor, TeX front end, CCMS, or layout application. The primary-source landscape indicates that no prominent current product cleanly owns that promise.

## Sources and scope note

This survey prioritizes first-party product documentation, vendor manuals, standards, and official project documentation. It assesses publicly documented product models and capabilities, not hands-on performance or subjective output quality. Historical Ventura Publisher and Interleaf are acknowledged as important conceptual ancestors, but detailed claims about discontinued versions were intentionally not built on secondary retrospectives. A later historical research pass using original manuals would be worthwhile when Folio begins documenting its design lineage.
