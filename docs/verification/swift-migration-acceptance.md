<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift migration integration and acceptance

This record covers the 2026-09-28 pre-alpha conversion batch, issues #31–#40.
The maintainer authorized rapid implementation and a reviewable PR stack; merging
and human/platform acceptance remain separate actions. The baseline and old-writer
fixtures are recorded in [Swift migration baseline](swift-migration-baseline.md).

## Historical status

The implementation inventory and results below describe the migration batch at
its recorded commits. Later cleanup is documented in [Swift cleanup](swift-cleanup.md).
On 2026-09-30 the maintainer retired the old-writer compatibility fixtures and
the Objective-C capture recipe; [baseline provenance](swift-migration-baseline.md#historical-status)
retains their Git locations. Current save/reopen and resource-preservation tests
use freshly generated Documents. Historical passing results below remain valid;
they do not imply an ongoing support promise for the retired pre-alpha writer.

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
| I1 integration / A1 evidence | #76 | all above |

The final integration branch contains each source branch as ancestry and adds
bridge removal, package pins, lint, public-consumer checks, localization extraction,
and shared test configuration. It can be reviewed against `main` as one Suite.
No source PR alone is a claim that the whole migration has passed acceptance.

## Production and interoperability inventory

Production applications, domain Kits, services, and tests use Swift 6. Immutable
Folio values are structs; Work and AppKit owners declare main-actor isolation;
Core Data managed objects stay inside private store operations. No temporary
Objective-C model or staging adapters remain.

Exceptions retained at the migration snapshot were intentional:

- Kit umbrella headers/module maps exported framework identity and version symbols
  at this migration snapshot. The subsequent Swift cleanup removed them; current
  Kits publish Swift modules without authored module maps or exported headers.
- Swift `@objc` runtime names preserve storyboard/document registration and XPC
  selectors; AppKit, Core Data and Core Text remain the implementation frameworks.
- Three Objective-C files under `Composer/Prototypes/ParagraphComposition` retain
  the original typography evidence and provenance.
- The [historical Objective-C capture recipe](https://github.com/Folio-Suite/Folio/blob/b5f42c2/scripts/capture-migration-baseline-fixtures.m)
  required baseline framework products. It was retained for the migration and
  retired with the fixtures on 2026-09-30.
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

Local execution used Xcode 27 on macOS 27 (26A428), arm64. The final runtime
repairs are in `a1746b3`; preceding integration/review commits are `fc30a7a`,
`aba22d8`, and `8339aa1`. Subsequent evidence-only commits do not change binaries.

| Check | Result |
| --- | --- |
| Signed Folio build-for-testing | Passed after final runtime repairs. |
| Full native plan | 54 distinct tests / 117 executions: 52 passed, two test assertions failed. The initial interrupted run was stopped while XCTest waited for diagnostic crash logs. |
| Affected native rerun | All 31 passed: all 23 WriteKit tests, four TypographyKit tests, two ComposerKit tests, and two Composer UI tests. This rerun repairs both failures and verifies the actual composed canvas. No runtime warnings. Together the full run and affected rerun cover all 54 tests. |
| Universal build | arm64 and x86_64 build passed with macOS 14 deployment settings. This is build coverage, not Intel/Sonoma runtime evidence. |
| Public interfaces | Swift consumers compile/link for both architectures; private symbols are rejected; isolated TypographyKit and UndoKit imports pass. |
| DocC | All six Kit catalogs generate. Project-owned unresolved-symbol and concurrency diagnostics were corrected. |
| Signatures and identity | Shared team, Hardened Runtime, library validation and 0.1.0 (1) bundle identity checks pass. |
| XPC transport | All three services echo the nonce from distinct processes in a signed temporary development harness with current framework/package dependencies. |
| Ruby tooling | 17 tests / 144 assertions pass, including signed package dependency fixtures and aliased staging paths. |
| Localization and lint | Swift/Interface Builder extraction check passes. SwiftLint has zero errors; 124 nonblocking style warnings remain under the imported policy. |
| Installer staging | Universal development products produce a PKG; package frameworks and Swift compatibility runtime are retained. Nothing was installed. |

Local artifacts are under `/tmp/folio-swift-loop`: `SwiftSuiteFinalTests.xcresult`
(full run), `SwiftRepairTests.xcresult` (passing affected rerun),
`universal-reviewed.log`, `universal-interfaces-final.log`,
`integration-xpc-development.log`, `tooling-tests-final.log`, and the staged
`package-reviewed/Folio-0.1.0.1.pkg`. These are development evidence, not release
artifacts. Hosted CI status is attached to PR #76's exact current head.

### Standards review

The independent standards review found one P2: overview documentation still
claimed Objective-C production and a typography scaffold. The pages now describe
the implemented Swift modules and bounded compositor. Follow-up review found no
remaining standards issue.

### Specification review

The independent spec review found a P1 duplicate-font dictionary trap and a P2
Window menu rename. Duplicate Core Text font runs now merge provenance safely;
a public regression covers disallowed/allowed fallback. The Window menu item,
system submenu and catalog are restored. Follow-up review confirmed the fixes.

Native execution also corrected an explicit-Undo-group omission in a migrated
test and the fallback test's expected `infeasible` status. Runtime diagnostics
exposed an incorrectly qualified storyboard class name; the canvas now resolves
its preserved Objective-C name, and its UI test requires the composed source
value as well as the visible heading. These affected suites pass.

Reproduction commands are `scripts/check-build.sh --analyze`,
`ruby scripts/ci.rb <new-output-directory>`, `ruby scripts/update-localizations.rb`,
and the Ruby tests under `scripts/tests/`. Use the pinned plugin approval policy
from CONTRIBUTING. Run `docbuild` on the shared Folio scheme for Kit catalogs.

## Maintainer acceptance and temporary waiver

On 2026-09-28 the maintainer supplied the human acceptance disposition for this
pre-alpha milestone:

- **Typography accepted.** The maintainer accepts the prior day's typography
  review and the decision to build Folio's own engine on Core Text as sufficient
  for this milestone. This does not claim a separate human review of every new
  rendered result or mature typography support.
- **Keyboard, focus and VoiceOver accepted.** The maintainer reports that these
  are basically functional and accepts the current behavior at pre-alpha scope.
  Editing, Undo, saving and reopening retain the automated evidence above.
- **Sonoma testing and installation verification temporarily waived.** The
  maintainer explicitly waives these checks while the project remains in its
  early, breakage-tolerant phase. Sonoma runtime, clean installation, Finder and
  installed-framework resolution are unverified. Intel runtime also remains
  unrun; the recorded Intel evidence is universal build/interface coverage.

This disposition resolves the milestone's human/platform acceptance gate for
#40. The waiver is temporary and does not establish OS, hardware or deployment
proof for a later release. PR #76 may resolve #37, #38 and #40 when the coordinated
stack merges; this acceptance does not itself merge the stack.

Full hosted CI passed on implementation/evidence head
`2bd244a99e2556db43437e7bc0919da1b94b7a3a`: Core, Write, Research, Composer,
Suite analysis/build/repository checks, and the final Suite gate all passed in
[run 36499796715](https://github.com/Folio-Suite/Folio/actions/runs/36499796715).
This acceptance update changes documentation only.

This batch implements neither durable history, shared domain hosts, `.folio`
archives, a Research catalog, Arrangement persistence, paragraph optimization,
complex-script/math layout, nor publication conformance. Those retain their
[successor tickets](../plans/accepted-backlog.md).
