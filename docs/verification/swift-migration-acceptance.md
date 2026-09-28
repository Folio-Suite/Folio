<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift migration integration and acceptance

This record covers the 2026-09-28 pre-alpha conversion batch, issues #31–#40.
The maintainer authorized rapid implementation and a reviewable PR stack; merging
and human/platform acceptance remain separate actions. The baseline and old-writer
fixtures are recorded in [Swift migration baseline](swift-migration-baseline.md).

## Review stack

| Slice | PR | Base |
| --- | --- | --- |
| Shared Core project | #68 | main |
| M0 baseline | #69 | #68 |
| M1 FolioKit values/staging | #70 | #69 |
| M2/M3 Write persistence and editing | #75 | #70 |
| M4 Research | #73 | #70 |
| M5 Composer shell | #71 | #70 |
| T1 TypographyKit | #72 | #69 |
| C1 Composer preview | #74 | #71 and #72 |
| I1 integration / A1 evidence | coordinated integration PR | all above |

The final integration branch contains each source branch as ancestry and adds
bridge removal, package pins, lint, public-consumer checks, localization extraction,
and shared test configuration. It can be reviewed against `main` as one Suite.
No source PR alone is a claim that the whole migration has passed acceptance.

## Production and interoperability inventory

Production applications, domain Kits, services, and tests use Swift 6. Immutable
Folio values are structs; Work and AppKit owners declare main-actor isolation;
Core Data managed objects stay inside private store operations. No temporary
Objective-C model or staging adapters remain.

Retained exceptions are intentional:

- Kit umbrella headers/module maps export framework identity and version symbols.
- Swift `@objc` runtime names preserve storyboard/document registration and XPC
  selectors; AppKit, Core Data and Core Text remain the implementation frameworks.
- Three Objective-C files under `Composer/Prototypes/ParagraphComposition` retain
  the original typography evidence and provenance.
- `scripts/capture-migration-baseline-fixtures.m` preserves the historical writer
  fixture recipe; it requires baseline framework products.
- `scripts/xpc-probe/main.m` is an independent Objective-C runtime client of the
  Swift services. Its separate protocol declarations detect selector drift.

Each of the six projects pins Defaults 9.0.9, swift-collections 1.7.1,
swift-algorithms 1.2.1 and SwiftLintPlugins 0.65.1. SwiftLint configuration comes
from KitchenMemory, with Folio paths and AppKit-appropriate rules. CI explicitly
uses `-skipPackagePluginValidation`; interactive Xcode retains first-run approval.

## Specification audit

These rows account for all 53 stories from #29. "Implemented" describes source
scope; runtime and human evidence is recorded separately below.

| Stories | Implementation / evidence seam |
| --- | --- |
| 1–3 | Swift production inventory; existing domain ownership retained. |
| 4–5 | macOS 14 settings and supported build architectures retained; Sonoma/Intel runtime pending. |
| 6–8 | Existing AppKit/storyboards/Core Data resources retained; separate dependency-ordered PRs. Native workflows below. |
| 9–11 | FolioKit immutable text/formatting values and WriteKit persistence tests, including baseline-writer fixture. |
| 12–14 | WriteKit selected-state formatting, warning conversion/dismissal, and non-authored diagnostic tests. |
| 15–16 | Native Undo registration and Manuscript reveal behavior; editor/Manuscript tests and native workflows. |
| 17–18 | Internal paste preserves semantics with independent paragraph IDs; external paste remains plain text. |
| 19–20 | Content Unit creation/selection/rename/order and snapshot persistence; transient selection remains in controllers. |
| 21 | Storyboard control identity and accessibility attributes retained; native UI assertions supplement pending human review. |
| 22–24 | Old-writer Work/Research fixtures, save/reopen and invalid-input preservation tests. |
| 25–28 | Existing document types/schema/enum values retained; private Kit stores and throwing temporary staging. `.folio` remains future work. |
| 29–30 | Public Swift modules, app imports, external positive/private-negative consumers, and DocC. |
| 31–34 | Value snapshots, validated identifiers/errors, explicit isolation, private focused store/editor modules. |
| 35–36 | Swift string extraction, public interface script, shared schemes, signing/product/tool checks. |
| 37 | Retained-language exceptions enumerated above. |
| 38–40 | Independent TypographyKit request/result API and ComposerKit adapter; one retained result supplies geometry and drawing. |
| 41–43 | Explicit breaks/discretionaries and bounded spacing/tracking/expansion/protrusion; public behavior fixtures. No break optimizer. |
| 44–45 | Language/script/direction/fallback are explicit. Initial realization is Latin LTR; complex scripts and formula layout remain language/math successors #60–#61. |
| 46–48 | Occurrence/source/discretionary mappings, fonts/environment provenance and structured complete/unsupported/infeasible outcomes. |
| 49–50 | Original native comparison evidence preserved; bounded engine and preview are distinct from mature typesetting. |
| 51–53 | Independent Swift UndoKit scaffold, source/design/license/history import retained. Durable history and external distribution remain deferred. |

## Verification results

Integrated build, native tests, public consumers, DocC and final review results are
being recorded against the final integration revision. See the PR for current
execution status until this section is finalized.

## Remaining human and platform evidence

Issue #40 remains open until the maintainer disposes of these acceptance items:

- Human typography review of the controlled Composer preview and retained specimens.
- Human keyboard/focus/VoiceOver review, formatting, chronological Undo, save and reopen.
- Representative macOS 14 Sonoma and Intel runtime workflows; the available local
  test host is macOS 27 on Apple Silicon.
- Installed changed-framework resolution outside Xcode and clean-install/Finder
  behavior. Build products and a development XPC probe do not prove deployment.

This batch implements neither durable history, shared domain hosts, `.folio`
archives, a Research catalog, Arrangement persistence, paragraph optimization,
complex-script/math layout, nor publication conformance. Those retain their
[successor tickets](../plans/accepted-backlog.md).
