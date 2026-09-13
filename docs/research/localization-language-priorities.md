<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio UI language priorities: audience research

Research date: 2026-09-12. Scope: a proposed localization roadmap for the native macOS Folio writing, research, and publishing suite. This is a recommendation, not an adopted product decision or an implementation change.

## Recommendation

Budget for **10 maintained UI localizations**, staged rather than shipped simultaneously:

| Stage | Localization | Proposed identifier | Reason for priority |
| --- | --- | --- | --- |
| Foundation | English | `en` | Existing source language and fallback; its position is a project choice. |
| First release group | Spanish | `es` | Strong international reach; develop terminology with Spain and Latin American reviewers. |
| First release group | French | `fr` | Broad international reach plus directly relevant publishing activity. |
| First release group | German | `de` | Strong publishing-market evidence; useful early expansion/layout test. |
| First release group | Japanese | `ja` | Both Apple regional-market evidence and publishing evidence; exercises non-Latin UI early. |
| First release group | Simplified Chinese | `zh-Hans` | Early coverage of a major Apple geographic market, with a separate script localization. |
| Second release group | Brazilian Portuguese | `pt-BR` | Broad language reach; target one named variant first, avoiding a claim of universal Portuguese localization. |
| Second release group | Traditional Chinese | `zh-Hant` | Complements Simplified Chinese; requires its own reviewed terminology and script, not just character conversion. |
| Second release group | Korean | `ko` | Strong publishing evidence, though weaker direct Mac-audience evidence. |
| Second release group | Italian | `it` | Relevant publishing and translation-market evidence. |

This gives English plus five translations first, then four more. The ordering is a judgment combining reach, relevance to this product, and a maintainable translation workload. It is **not** a statistically proven optimum. A credible native reviewer and actual interested users can justify moving a language earlier.

**Arabic (`ar`, Modern Standard Arabic UI)** is the leading next expansion candidate. It would be reasonable to include it as localization 11 if inclusive reach is weighted above the convenience of another left-to-right language. Regardless of shipping order, exercise right-to-left UI and Arabic mixed-direction document content now. Do not defer the architectural capability with the translation.

## What the evidence supports

- **Spanish:** Instituto Cervantes reports over 630 million potential speakers and over 500 million native-proficiency speakers in 2025. These are language-community estimates, not software customers. [Cervantes, 2025 introduction](https://cvc.cervantes.es/lengua/anuario/anuario_25/moreno-alvarez/p01.htm)
- **French:** OIF estimates 396 million speakers for 2025 in its 2026 report. Its new method includes certain children aged 6–9 learning to read in French; the headline therefore must not be interpreted as uniform adult fluency or a directly comparable customer count. [OIF report, pages 5–7](https://www.francophonie.org/sites/default/files/2026-04/Synthese_rapport_Langue_francaise_dans_le_monde_2026.pdf)
- **Portuguese:** UNESCO reports over 265 million speakers across continents. Brazil's official 2025 population estimate is 213.4 million, supporting Brazil as a sensible initial regional focus; population is not itself a Portuguese-speaker or Mac-owner count. [UNESCO](https://www.unesco.org/pt/days/portuguese-language), [IBGE](https://educa.ibge.gov.br/jovens/materias-especiais/23077-populacao-estimada-passa-213-milhoes.html)
- **Arabic:** UNESCO describes over 400 million daily speakers. This makes indefinite exclusion difficult to justify if broad usefulness is the goal, even though the current sources do not establish Folio demand. [UNESCO](https://www.unesco.org/ar/world-arabic-language-day)
- **Publishing relevance:** WIPO's report covering 2022 records publishing revenue of roughly $9.9 billion for Germany and $9.3 billion for Japan. It cites $6.7 billion for Korea in 2021 because 2022 data was unavailable. Italy and Brazil each reported over 100,000 titles in 2022. These are historical country-sector observations, not a current complete world ranking or language-specific demand. WIPO cautions that collection scopes differ. [WIPO report, pages 6–8 and 27](https://www.wipo.int/edocs/pubdocs/en/wipo-pub-1064-2023-2-en-the-global-publishing-industry-in-2022.pdf)
- **Current translation-market corroboration:** France's publishing association reports 2025 translation-rights transactions led by Italian, followed by Spanish, Chinese, English, and German. This is evidence of active language relationships in publishing, not a global ranking. [SNE, 2025 figures](https://www.sne.fr/economie/chiffres-cles/)
- **Apple relevance:** Apple's FY2025 report lists $64.377 billion of net sales for Greater China and $28.703 billion for Japan. Greater China includes mainland China, Hong Kong, and Taiwan. These are all-product sales, not Mac sales by language. Even Apple's “Europe” segment includes India, the Middle East, and Africa. The report separately supplies worldwide Mac revenue, but does not provide a language-specific Mac installed-base table. The defensible inference is that East Asian localizations deserve serious consideration; these totals cannot substantiate a percentage of reachable Mac users. [Apple FY2025 Form 10-K](https://www.sec.gov/Archives/edgar/data/320193/000032019325000079/aapl-20250927.htm)

## Variants and boundaries

Use the table's identifiers as planning labels; validate exact Xcode configuration separately. Apple itself distinguishes Latin American Spanish, Canadian French, Brazilian/European Portuguese, and mainland/Hong Kong/Taiwan Chinese in its own localization portfolio. That establishes a useful precedent for variants, not a requirement to reproduce its full catalog. [Apple Partner Media Review localization list](https://itunespartner.apple.com/tv-movies/support/5429-languages-apple-partner-media-review)

For a small initial catalog, prefer one carefully reviewed broadly usable Spanish and French UI before adding regional copies. Add `es-419`, `fr-CA`, `pt-PT`, or region-specific Chinese when users and reviewer feedback identify meaningful differences. Simplified and Traditional Chinese should remain two localization workstreams. Do not count them as two unrelated spoken languages; do not call `zh-Hans` “Mandarin.”

The UI language list must not become a whitelist of languages users may write. Document language, spelling, typography, mixed scripts, dates, and export fidelity have separate requirements from translated menus. An English UI should still permit Arabic, Hindi, Ukrainian, or multilingual work.

## Uncertainty and decision rule

These sources do not yield a reliable “X% of all users” claim. Speaker counts overlap through multilingualism; buying a Mac, writing, language preference, and willingness to use Folio are separate filters. Publishing data is only a product-relevance proxy. No source establishes that Italian will outperform Arabic, Hindi, Indonesian, Russian, Turkish, Polish, or Dutch for Folio.

Before expanding beyond the initial cohort, use actual requests, active volunteer/native reviewers, translation completeness, and successful end-to-end editing/export checks. Hindi, Indonesian, Arabic, and the other candidates should be evaluated on that evidence rather than permanently excluded by this first roadmap. Keep translated UI complete enough to maintain trust, and treat a supported locale as an ongoing release obligation.

Candidate-specific judgment: Arabic has the clearest immediate inclusion case from the reach evidence above and can move ahead of Italian or Korean. Hindi deserves an early demand check, but country-wide Indian publishing revenue cannot be assigned to Hindi or to Hindi-preferring Mac users. Russian deserves a demand check and brings Cyrillic coverage; this review did not find enough first-party Folio/Mac-language evidence to rank it against the final four confidently. These are provisional backlog decisions, not a claim that the languages are less important or that English adequately serves their speakers.

Apple's current Xcode guidance recommends the most specific appropriate localization. Accordingly, generic tags in this shortlist identify language workstreams only: choose each actual region/script setting with the intended audience and translator before creating production locales. “Broadly usable Spanish” is an editorial aspiration to validate, not an Apple-prescribed fallback strategy. [Apple, Choosing localization regions and scripts](https://developer.apple.com/documentation/xcode/choosing-localization-regions-and-scripts)

## Preparation implications for the native Suite

Local checkout inspected on 2026-09-12: five `Localizable.xcstrings` files exist across FolioKit, Write, WriteKit, Research, and ResearchKit, with English as the source language. The Write app catalog inspected is empty. This confirms the starting structure, not completed string extraction or working translations. Existing user changes were left untouched.

Recommended next implementation slice, independent of the final translation roster:

1. Audit user-visible strings in code, storyboards, menus, errors, accessibility labels, and Help. Populate catalogs through supported localization APIs and verify extraction; adding a catalog alone is insufficient. Supply translator context for Folio terms such as Work, Manuscript, Source, Edition, and Rendition. Use complete messages and language-specific plural variants. [Apple: string catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
2. Make resource ownership explicit across the Suite. Kit-owned strings must resolve from their owning framework bundle. Foundation's default lookup uses the main bundle, so a catalog in a Kit does not make a default application-bundle lookup correct. Verify a Kit string in both relevant app contexts where reused. [Apple: NSLocalizedString](https://developer.apple.com/documentation/foundation/nslocalizedstring(_:tablename:bundle:value:comment:))
3. Exercise long labels, accents, and right-to-left layout before translating. Use Xcode pseudolanguages and Interface Builder previews. Add real Arabic mixed with Latin text and numbers to the editor test material: a mirrored English interface is useful layout evidence but does not prove bidirectional editing. [Apple: localization testing, archived](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html), [Apple: Get it right (to left)](https://developer.apple.com/videos/play/wwdc2022/10107/)
4. Keep interface locale, regional formatting, and the language of authored content separate. Proposed Folio policy: a Work can contain multiple languages regardless of the UI translation list; localized display names must not change persistent semantic identifiers. Writing, shaping, search, spelling, hyphenation, and publication typography need their own capability checks. A translated menu does not establish support for all those operations. This is a product recommendation, not a claim that Folio currently implements them.
5. Ship a localization only after terminology review by a fluent reviewer and an in-app pass through menus, dialogs, errors, accessibility, and core workflows. Test language and region independently, including fallback, plural messages, and resource loading. Catalog completion is necessary but not sufficient. [Apple: testing localizations](https://developer.apple.com/documentation/xcode/testing-localizations-when-running-your-app)

The language roster is a planning proposal. This research does not adopt an ADR, change project settings, populate translations, or claim production localization readiness.
