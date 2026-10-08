<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Accepted plan: ticket handoff

The maintainer accepted specification #29 and its migration sequence on 2026-09-27, then authorized publication and retirement of the original UndoKit repository after preservation. This handoff performs no product implementation. [ADR 0015](../adr/0015-swift-suite-and-independent-frameworks.md) records the adopted direction.

The source and distribution plan was subsequently refined by [ADR 0019](../adr/0019-undokit-package-boundary.md): the old repository remains retired, while the new Folio-Suite repository is tracked as a submodule. Its Swift Package product remains available to other consumers. Objective-C interfaces and XCFramework distribution remain deferred.

There are 36 successor tickets: ten migration/acceptance slices, eleven retained UndoKit decisions/proofs, and fifteen follow-on slices or design questions. Implementation/preparation tickets carry `ready-for-agent`; design and proof tickets carry `needs-triage` and require the stated human review. Native GitHub parent and blocking relationships are authoritative. A ready label never bypasses open blockers. Completed U0/T0 scaffolds and probe #22 are referenced, not duplicated.

## Ticket graph

| Code | Ticket | Blocked by | Kind |
| --- | --- | --- | --- |
| M0 | [#31](https://github.com/Folio-Suite/Folio/issues/31) Capture the accepted Swift migration baseline | None | task |
| M1 | [#32](https://github.com/Folio-Suite/Folio/issues/32) Use Swift FolioKit through the existing Suite consumers | [#31](https://github.com/Folio-Suite/Folio/issues/31) | task |
| M2 | [#33](https://github.com/Folio-Suite/Folio/issues/33) Reopen and save Works through Swift persistence | [#32](https://github.com/Folio-Suite/Folio/issues/32) | task |
| M3 | [#34](https://github.com/Folio-Suite/Folio/issues/34) Preserve the complete Write editing workflow in Swift | [#33](https://github.com/Folio-Suite/Folio/issues/33) | task |
| M4 | [#35](https://github.com/Folio-Suite/Folio/issues/35) Preserve Source Library documents in Swift Research | [#32](https://github.com/Folio-Suite/Folio/issues/32) | task |
| M5 | [#36](https://github.com/Folio-Suite/Folio/issues/36) Preserve the Composer shell in Swift | [#32](https://github.com/Folio-Suite/Folio/issues/32) | task |
| T1 | [#37](https://github.com/Folio-Suite/Folio/issues/37) Realize controlled text through TypographyKit | [#31](https://github.com/Folio-Suite/Folio/issues/31) | task |
| C1 | [#38](https://github.com/Folio-Suite/Folio/issues/38) Compose a bounded Composer preview through TypographyKit | [#36](https://github.com/Folio-Suite/Folio/issues/36), [#37](https://github.com/Folio-Suite/Folio/issues/37) | task |
| I1 | [#39](https://github.com/Folio-Suite/Folio/issues/39) Integrate the coordinated Swift Suite and remove transition bridges | [#34](https://github.com/Folio-Suite/Folio/issues/34), [#35](https://github.com/Folio-Suite/Folio/issues/35), [#38](https://github.com/Folio-Suite/Folio/issues/38) | task |
| A1 | [#40](https://github.com/Folio-Suite/Folio/issues/40) Verify and accept the Swift migration | [#39](https://github.com/Folio-Suite/Folio/issues/39) | task |
| U1 | [#41](https://github.com/Folio-Suite/Folio/issues/41) Define UndoKit durable acceptance and interruption recovery | None | grilling |
| U2 | [#42](https://github.com/Folio-Suite/Folio/issues/42) Define UndoKit branches, checkpoints, and bounded retention | None | grilling |
| U3 | [#43](https://github.com/Folio-Suite/Folio/issues/43) Define typed Swift UndoKit payload and host interfaces | [#41](https://github.com/Folio-Suite/Folio/issues/41) | grilling |
| U4 | [#44](https://github.com/Folio-Suite/Folio/issues/44) Define native UndoKit routing and restored availability | [#41](https://github.com/Folio-Suite/Folio/issues/41), [#42](https://github.com/Folio-Suite/Folio/issues/42) | grilling |
| U5 | [#45](https://github.com/Folio-Suite/Folio/issues/45) Define UndoKit store lifecycle and safe capacity | [#41](https://github.com/Folio-Suite/Folio/issues/41), [#42](https://github.com/Folio-Suite/Folio/issues/42), [#43](https://github.com/Folio-Suite/Folio/issues/43) | grilling |
| U6 | [#46](https://github.com/Folio-Suite/Folio/issues/46) Set UndoKit acceptance scenarios and measured budgets | [#44](https://github.com/Folio-Suite/Folio/issues/44), [#45](https://github.com/Folio-Suite/Folio/issues/45) | grilling |
| UP1 | [#47](https://github.com/Folio-Suite/Folio/issues/47) Prove UndoKit interruption recovery and durable invalidation | [#46](https://github.com/Folio-Suite/Folio/issues/46) | prototype |
| UP2 | [#48](https://github.com/Folio-Suite/Folio/issues/48) Prove UndoKit native restoration and focus behavior | [#46](https://github.com/Folio-Suite/Folio/issues/46) | prototype |
| UP3 | [#49](https://github.com/Folio-Suite/Folio/issues/49) Prove UndoKit package and compatibility failure preservation | [#46](https://github.com/Folio-Suite/Folio/issues/46) | prototype |
| UP4 | [#50](https://github.com/Folio-Suite/Folio/issues/50) Prove UndoKit branching and retention at the agreed scale | [#46](https://github.com/Folio-Suite/Folio/issues/46) | prototype |
| U7 | [#51](https://github.com/Folio-Suite/Folio/issues/51) Accept UndoKit design for Folio implementation | [#47](https://github.com/Folio-Suite/Folio/issues/47), [#48](https://github.com/Folio-Suite/Folio/issues/48), [#49](https://github.com/Folio-Suite/Folio/issues/49), [#50](https://github.com/Folio-Suite/Folio/issues/50) | grilling |
| S1 | [#52](https://github.com/Folio-Suite/Folio/issues/52) Save Work changes without rewriting unchanged content and assets | [#40](https://github.com/Folio-Suite/Folio/issues/40) | task |
| H1 | [#53](https://github.com/Folio-Suite/Folio/issues/53) Reopen a Work with durable Undo and checkpoint restoration | [#52](https://github.com/Folio-Suite/Folio/issues/52), [#51](https://github.com/Folio-Suite/Folio/issues/51) | task |
| R0 | [#54](https://github.com/Folio-Suite/Folio/issues/54) Specify the first Library and Work-local citation workflow | [#34](https://github.com/Folio-Suite/Folio/issues/34), [#35](https://github.com/Folio-Suite/Folio/issues/35) | grilling |
| D0 | [#55](https://github.com/Folio-Suite/Folio/issues/55) Specify one shared Work host and embedded editing handoff | [#34](https://github.com/Folio-Suite/Folio/issues/34), [#41](https://github.com/Folio-Suite/Folio/issues/41) | grilling |
| R1 | [#56](https://github.com/Folio-Suite/Folio/issues/56) Specify optional paired bibliographic synchronization | [#54](https://github.com/Folio-Suite/Folio/issues/54), [#55](https://github.com/Folio-Suite/Folio/issues/55) | grilling |
| C2 | [#57](https://github.com/Folio-Suite/Folio/issues/57) Specify saved Arrangements and self-contained Editions | [#36](https://github.com/Folio-Suite/Folio/issues/36) | grilling |
| X1 | [#58](https://github.com/Folio-Suite/Folio/issues/58) Specify portable XML Document exchange and Project collection | [#53](https://github.com/Folio-Suite/Folio/issues/53), [#54](https://github.com/Folio-Suite/Folio/issues/54), [#57](https://github.com/Folio-Suite/Folio/issues/57) | grilling |
| T2 | [#59](https://github.com/Folio-Suite/Folio/issues/59) Select whole-paragraph breaks with explicit constraints | [#37](https://github.com/Folio-Suite/Folio/issues/37) | task |
| T3 | [#60](https://github.com/Folio-Suite/Folio/issues/60) Specify the first licensed language hyphenation package | [#37](https://github.com/Folio-Suite/Folio/issues/37) | grilling |
| T4 | [#61](https://github.com/Folio-Suite/Folio/issues/61) Specify a bounded mathematical typography operation | [#37](https://github.com/Folio-Suite/Folio/issues/37) | grilling |
| T5 | [#62](https://github.com/Folio-Suite/Folio/issues/62) Prove coordinated Streams and paged reconsideration | [#38](https://github.com/Folio-Suite/Folio/issues/38), [#59](https://github.com/Folio-Suite/Folio/issues/59) | prototype |
| W1 | [#63](https://github.com/Folio-Suite/Folio/issues/63) Specify the first reusable review and definition-design workflows | [#54](https://github.com/Folio-Suite/Folio/issues/54), [#57](https://github.com/Folio-Suite/Folio/issues/57) | grilling |
| P1 | [#64](https://github.com/Folio-Suite/Folio/issues/64) Specify paged output preflight and PDF acceptance | [#62](https://github.com/Folio-Suite/Folio/issues/62), [#57](https://github.com/Folio-Suite/Folio/issues/57) | grilling |
| P2 | [#65](https://github.com/Folio-Suite/Folio/issues/65) Specify a semantic EPUB rendition workflow | [#57](https://github.com/Folio-Suite/Folio/issues/57) | grilling |
| P3 | [#66](https://github.com/Folio-Suite/Folio/issues/66) Specify a semantic static-web rendition workflow | [#57](https://github.com/Folio-Suite/Folio/issues/57) | grilling |

## Specification coverage

All 53 stories remain in the canonical specification. Story 52 is expressly amended to require independent Swift module use; external Objective-C/XCFramework distribution is deferred until after Folio 1.0. M0 inventories the entire contract; A1 audits its implementation and evidence. The table below identifies the substantive owning slices rather than counting those two audits as implementation coverage.

| Story | Owning slice(s) |
| --- | --- |
| 1 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 2 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 3 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 4 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 5 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 6 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 7 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 8 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 9 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 10 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 11 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 12 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 13 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 14 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 15 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#53](https://github.com/Folio-Suite/Folio/issues/53) (H1) |
| 16 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#53](https://github.com/Folio-Suite/Folio/issues/53) (H1) |
| 17 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 18 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 19 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 20 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3) |
| 21 | [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 22 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#52](https://github.com/Folio-Suite/Folio/issues/52) (S1) |
| 23 | [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 24 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#52](https://github.com/Folio-Suite/Folio/issues/52) (S1) |
| 25 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#58](https://github.com/Folio-Suite/Folio/issues/58) (X1) |
| 26 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#52](https://github.com/Folio-Suite/Folio/issues/52) (S1) |
| 27 | [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#52](https://github.com/Folio-Suite/Folio/issues/52) (S1) |
| 28 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#52](https://github.com/Folio-Suite/Folio/issues/52) (S1) |
| 29 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 30 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 31 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 32 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 33 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 34 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 35 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 36 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 37 | [#32](https://github.com/Folio-Suite/Folio/issues/32) (M1), [#33](https://github.com/Folio-Suite/Folio/issues/33) (M2), [#34](https://github.com/Folio-Suite/Folio/issues/34) (M3), [#35](https://github.com/Folio-Suite/Folio/issues/35) (M4), [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 38 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1) |
| 39 | [#36](https://github.com/Folio-Suite/Folio/issues/36) (M5), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1) |
| 40 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2) |
| 41 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2), [#60](https://github.com/Folio-Suite/Folio/issues/60) (T3) |
| 42 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2) |
| 43 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2) |
| 44 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2), [#60](https://github.com/Folio-Suite/Folio/issues/60) (T3) |
| 45 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#61](https://github.com/Folio-Suite/Folio/issues/61) (T4) |
| 46 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2), [#61](https://github.com/Folio-Suite/Folio/issues/61) (T4) |
| 47 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2), [#60](https://github.com/Folio-Suite/Folio/issues/60) (T3), [#61](https://github.com/Folio-Suite/Folio/issues/61) (T4) |
| 48 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2), [#61](https://github.com/Folio-Suite/Folio/issues/61) (T4) |
| 49 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2) |
| 50 | [#37](https://github.com/Folio-Suite/Folio/issues/37) (T1), [#38](https://github.com/Folio-Suite/Folio/issues/38) (C1), [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#59](https://github.com/Folio-Suite/Folio/issues/59) (T2) |
| 51 | [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#53](https://github.com/Folio-Suite/Folio/issues/53) (H1) |
| 52 | [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#53](https://github.com/Folio-Suite/Folio/issues/53) (H1) |
| 53 | [#39](https://github.com/Folio-Suite/Folio/issues/39) (I1), [#53](https://github.com/Folio-Suite/Folio/issues/53) (H1) |

Typography stories include both foundation support and later behavior: T1/C1 define the supported subset; paragraph optimization, language packages and mathematical layout have separate completion criteria. Remaining Source schemas, host transport, archive encodings, production workflows and output standards are explicit design successors. They do not reopen the accepted three-app, Core Data, Core Text or document-ownership choices.

## Scope and handoff rules

- Work from closed blockers and the selected ticket's scope. No ticket was claimed and no implementation started during this handoff.
- M2/M3 may share an integration branch if a temporary adapter cannot preserve green intermediate states; the combined result must pass before integration.
- Keep the agreed public Kit and native workflow test seams, independent expectations, old-writer fixtures and human typography/native-interaction review. Record missing Sonoma, Intel or installed-product evidence explicitly.
- UndoKit is Swift, Folio first and KitchenMemory second, with host-owned semantics and generic framework safeguards. Its unresolved decisions remain real gates for durable history; the architectural choice is complete.
- Helper apps require no project now. This handoff deferred external distribution until after a working Folio Suite 1.0; [ADR 0019](../adr/0019-undokit-package-boundary.md) later made the Swift framework and package available from a separate repository. Objective-C interfaces and XCFramework distribution remain deferred. Ordinary coordinated Suite packaging/signing/runtime verification remains in scope.
- Planning parents #29 and #2 close as completed specification/architecture handoffs. Their remaining child tickets track future delivery; parent closure does not assert product completion.

## UndoKit preservation

The maintainer accepted U6 ([#46](https://github.com/Folio-Suite/Folio/issues/46))
on 2026-09-29. The [measurement plan](../../UndoKit/docs/acceptance-measurement-plan.md)
records mandatory workloads, exploratory multi-GiB cases, advisory timings,
resource targets, candidate request limits, cancellation and four-proof evidence.
All #47–#50 proofs remain required and need maintainer review; numeric candidates
are not validated production ceilings. No benchmark is claimed passed.

The maintainer accepted U5 ([#45](https://github.com/Folio-Suite/Folio/issues/45))
on 2026-09-29. The [store-lifecycle contract](../../UndoKit/docs/store-lifecycle-contract.md)
records host registration, the app-owned Application Support default, ownership,
copying, compatibility, recovery, closing, checkpoints, omission and full-footprint
capacity safeguards. U6 now records candidate budgets; storage proof remains #49 with
related #47–#50 evidence. This accepts design without implementing persistence.

The maintainer accepted U4 ([#44](https://github.com/Folio-Suite/Folio/issues/44))
on 2026-09-29. The [native-routing contract](../../UndoKit/docs/native-routing-contract.md)
records the reusable bridge, ordered native invocations, host editing barriers,
local text and view policies, rejection, interference and restored availability.
Host obligations are normative documentation requirements. Concrete AppKit proof
remains in #48 under the accepted U6 plan; accepting design does not implement the bridge.

The maintainer accepted U3 ([#43](https://github.com/Folio-Suite/Folio/issues/43))
on 2026-09-29 after the isolated Swift feasibility proof. The
[typed-interface contract](../../UndoKit/docs/typed-interface-contract.md)
records adapters, codecs including binary property lists, asynchronous ordered
submission, bounded queries and the proof's limits. Prototype source and results
remain on a separate evidence branch. U4 and U5 record native routing and storage
lifecycle behavior; U6 records budgets and runtime proof continues in #47–#50.

The maintainer accepted U2 ([#42](https://github.com/Folio-Suite/Folio/issues/42))
on 2026-09-29. The [history-retention contract](../../UndoKit/docs/history-retention-contract.md)
records restoration, shared Undo/Redo depth, checkpoints, independent retention
holds and safe consolidation. This resolves the design gate; U6 now defines the
measurement plan and #50 owns branching/retention proof. The ticket graph above
records the original dependencies; GitHub carries live completion state.

The 2026-09-29 preservation inventory records original-to-successor issue mappings, preserved accepted research, the tracker snapshot, and Git recovery instructions. The original remote was confirmed deleted on 2026-09-27; original URLs remain as historical provenance. Current generic framework work belongs in the [UndoKit repository](https://github.com/Folio-Suite/UndoKit); Folio successor issues remain the tracker for host integration and Suite behavior.
