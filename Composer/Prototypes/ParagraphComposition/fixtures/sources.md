<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Paragraph composition specimens

Retrieved 2026-09-27. `specimens.json` contains the complete *corpus* (answer) of articles 1 and 2 of *Summa theologiae*, Prima pars, question 1, in Latin and English. Article 1 is the longer composition sample. Each answer occupies one paragraph in its cited electronic source. The fixture preserves that complete paragraph's wording and punctuation while replacing HTML line wraps and runs of whitespace with one space. It omits headings, argument labels, replies, and page furniture. These are layout specimens, not a claim that the English is a fresh translation.

## Latin

- Edition: Thomas Aquinas, *Summa theologiae*, Prima pars, [Leonine text published in Rome, 1888](https://bkv.unifr.ch/works/sth/versions/summa-theologiae), as transcribed by the University of Fribourg's *Bibliothek der Kirchenväter* (BKV). The selected [article 1](https://bkv.unifr.ch/works/sth/versions/summa-theologiae/divisions/6) and [article 2](https://bkv.unifr.ch/works/sth/versions/summa-theologiae/divisions/7) pages mark the answers `Iª q. 1 a. 1 co.` and `Iª q. 1 a. 2 co.` respectively. Direct downloads of both BKV pages confirmed that each fixture is the complete text of one `<p>` element after whitespace normalization. The [Latin Wikisource question page](https://la.wikisource.org/wiki/Summa_Theologiae/Prima_pars/Quaestio_I) was also checked; its [source note](https://la.wikisource.org/wiki/Disputatio:Summa_Theologiae/Prima_pars/Quaestio_I) links to Corpus Thomisticum. The fixture source URL points to BKV because BKV names its print edition and states its own reuse position.
- Reuse evidence: Aquinas's original text and the 1888 edition are historical. [BKV's copyright notice](https://bkv.unifr.ch/about/copyrights), verified by direct download, says in German that to its knowledge the texts are no longer under copyright and may be used freely; it asks, as a courtesy, for a source reference and corrected texts. This note supplies the source references. This is BKV's stated position, not an independent legal determination for every jurisdiction. BKV's site footer copyright concerns the site; it does not override the stated reuse permission for its texts. The separate [Corpus Thomisticum electronic edition](https://www.corpusthomisticum.org/sth0000.html) asserts rights in that edition and was not used as the fixture source.

## English

- Edition: Thomas Aquinas, *Summa Theologica*, Part I, translated by the Fathers of the English Dominican Province, Benziger Brothers, New York; [Project Gutenberg eBook 17611](https://www.gutenberg.org/cache/epub/17611/pg17611.html), produced by Sandra K. Perry and corrected and supplemented by David McClamrock. The electronic editor [describes transcription and citation changes](https://www.gutenberg.org/cache/epub/17611/pg17611.html) relative to the Benziger printing. The printed volume's precise publication year is not stated in this electronic edition, so the electronic edition is the exact fixture version. The eBook was released in 2006 and last updated in 2021, according to its [catalog record](https://www.gutenberg.org/ebooks/17611).
- Reuse evidence: The [catalog record](https://www.gutenberg.org/ebooks/17611) marks eBook 17611 “Public domain in the USA.” [Project Gutenberg's license explanation](https://www.gutenberg.org/policy/license.html) distinguishes the unrestricted book text from its trademark and license and permits reuse of the text in the United States once the Gutenberg notices and marks are stripped. The fixture includes only the translated answer text; its URL appears here and as source metadata for attribution, not as an eBook trademark or endorsement. Outside the United States, rights may differ.

## Transcription choices and integrity

- Both languages use the answer sections of the same two articles. All text within each source paragraph is present, including the opening formula and final sentence. Direct downloads of BKV and Project Gutenberg were compared to the JSON values after HTML tag removal, entity decoding, and whitespace normalization; all four matched exactly. No source paragraphs were joined. No ellipses, modernization, spelling fixes, or translation edits were made.
- The English article 1 Scripture reference is `Isa. 66:4` in the Gutenberg electronic text, while the Latin refers to `Isaiae LXIV`. The fixture keeps each source's reference rather than harmonizing them.
- SHA-256 below is calculated over the UTF-8 bytes of each JSON `text` value after decoding; it protects the chosen normalized fixture text, not the remote source page. Word counts split on spaces.

| Specimen | Words | SHA-256 of `text` |
| --- | ---: | --- |
| `latin-a1` | 165 | `79f44ee740e4dd4c486aa4fbf7b918b14a64583fb0c04851271acd34fb2b4640` |
| `english-a1` | 233 | `8b1898bb5b57e724743e472162ecd6a93d163ee2bd552771217b8a9a07cdaad9` |
| `latin-a2` | 96 | `555cbb8b3a307b7cc124520b9d882551066e0f448fb0d654034859b2da8eaffb` |
| `english-a2` | 131 | `728e94230356039f596b8caaa4462455a8f91b7ae015cc979ab1cf4acb3b9daa` |

The direct comparison verifies fidelity to the cited electronic paragraphs. A future editorial proof against the 1888 scan would strengthen a claim of character-for-character fidelity to that printing. For this prototype, the fixture is pinned to the cited electronic text and its hashes.
