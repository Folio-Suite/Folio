<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# SwiftUI suitability for Folio's desktop applications

Research date: 2026-09-13. Status: research for discussion; no architecture decision or implementation. Evidence: Apple documentation, sessions, samples, and release notes. No application benchmark or native interaction test was performed.

## Assessment

SwiftUI is a credible technology for substantial Mac interfaces. Public evidence does **not** establish that a pure SwiftUI implementation can satisfy Folio's complete semantic editor and document lifecycle with acceptable reliability and cost. Equally, it does not support dismissing SwiftUI as suitable only for simple apps. Apple documents native windows, contextual commands, editable attributed text, tables, accessibility, and integration in both directions with AppKit. The individual capabilities and their limits are examined below.

**Research recommendation:** keep Swift + AppKit and AppKit hosting bounded SwiftUI components as serious candidates. Evaluate a SwiftUI shell hosting an AppKit editor separately from a pure SwiftUI editor. Treat an all-SwiftUI choice as something that must earn its place through representative behavior, not through a language migration or a framework popularity argument. These are judgments about Folio's risks, not measured comparative failure rates.

Swift does not require SwiftUI. Apple's current `NSDocument` reference presents a Swift subclassing interface, and its AppKit integration tutorial implements Cocoa objects in Swift. A decision about Objective-C source therefore need not decide window ownership, editor technology, or persistence. This does not establish anything about an unannounced Objective-C or AppKit support timetable. [Apple: NSDocument](https://developer.apple.com/documentation/appkit/nsdocument), [Integrating AppKit](https://developer.apple.com/tutorials/app-dev-training/integrating-appkit)

## Repository context and constraints

Folio's [domain](../../CONTEXT.md) distinguishes a Work from a Manuscript, Source Library, Edition, and Rendition. Its [semantic model contract](../architecture/semantic-model-contract.md) includes identity and relationships that cannot be reduced to styled character runs. Notes, Citations, overlapping Editorial Annotations, Proposed Revisions, and unknown Semantic Vocabulary content matter to editing and preservation.

[CONTRIBUTING.md](../../CONTRIBUTING.md) currently specifies Xcode 26.6, macOS 26.5 as the minimum, storyboard-based app and Kit interfaces, and controllers for behavior. SwiftUI adoption would require deliberately revisiting that interface-authoring rule. The implemented Write and Research shells use NSDocument and in-process persistence; the helper-owned Work Session in [ADR 0004](../adr/0004-helper-owned-work-sessions.md) remains a contract with outstanding lifecycle proof, not an implemented foundation. [ADR 0005](../adr/0005-native-packages-and-archival-folios.md) requires native packages and distinguishes Save from archival folio export.

The older [language and integration research](macos-suite-language-and-integration-architecture.md) rated SwiftUI-first as a poor fit. This report qualifies that blanket rating with newer capability evidence and separates shell, editor, and lifecycle. Neither research note overrides the repository's adopted decisions.

## Availability: keep the baseline separate from the next API generation

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| WWDC24 Mac window sessions | Public SwiftUI APIs for window structure, placement, styling, sizing, and restoration choices predate the current deployment baseline. | Every professional window/panel arrangement behaves correctly in Folio. |
| WWDC25 rich text and performance sessions | The macOS 26 generation adds attributed TextEditor functionality and dedicated performance tooling. | A production-proven semantic manuscript editor or a Folio performance budget. |
| WWDC26 SwiftUI guide and session | Apple describes a new document API generation with incremental/asynchronous I/O and direct URL access, plus continued interoperation investment. | Availability on macOS 26.5, or stability demonstrated by shipping Folio workloads. |

Sources: [Tailor macOS windows, WWDC24](https://developer.apple.com/videos/play/wwdc2024/10148/), [Rich text, WWDC25](https://developer.apple.com/videos/play/wwdc2025/280/), [SwiftUI Instruments, WWDC25](https://developer.apple.com/videos/play/wwdc2025/306/), [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/).

Apple's live WWDC26 pages refer to the “2027 releases” and Xcode 27. The live `DocumentGroup` reference labels its new creation initializers **Beta**, while marking older overloads deprecated. Preserve those source labels rather than silently treating the new APIs as released macOS 26 functionality or inventing an OS mapping. Before an experiment depends on a new symbol, inspect its exact SDK availability and the OS build being run. This research does not certify the current release status of an entire OS from one API's documentation badge. [Apple: What's new in SwiftUI, WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/), [DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)

A local inspection of the installed Xcode macOS SDK’s SwiftUI declarations also confirmed macOS 26.0 availability for attributed `TextEditor`, `NSHostingSceneRepresentation`, and `NSGestureRecognizerRepresentable`, and macOS 14.4 for `NSHostingMenu`. Thus their discussion in WWDC26 does not make them future-only. This was declaration inspection, not compilation or runtime testing. Evidence: `SwiftUI.framework/Versions/A/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface` in the installed macOS SDK, declarations near lines 3061, 3964, 8091, and 20803; line numbers may change with SDK updates.

## Capability and risk by workflow

### Document lifecycle and shared authority

`DocumentGroup` supplies creation, opening, saving, and native document menu integration. Its established `FileDocument` / `ReferenceFileDocument` model is useful, but Apple explicitly warns against accessing managed document contents through the exposed URL outside the protocols' read/write facilities. That constraint matters to a package containing a live persistence store. It is not evidence that arbitrary parallel writers are supported. [Apple: DocumentGroup](https://developer.apple.com/documentation/swiftui/documentgroup)

The newer Document API adds direct coordinated URL access, snapshot-based change detection, and incremental/asynchronous reading and writing. This directly addresses some reasons large document apps have needed more control. It is a promising future comparison arm, not a solution available by assumption at Folio's minimum OS. [Apple: WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/), [Creating a document-based app](https://developer.apple.com/documentation/swiftui/creating-a-document-based-app)

`NSDocument` exposes window-controller ownership, edited state, undo, Save/Revert/Print responder actions, and version browsing. Those controls make it a useful comparison baseline; they do not automatically implement safe shared Work authority either. [Apple: NSDocument](https://developer.apple.com/documentation/appkit/nsdocument)

**Folio inference:** whichever shell is used, UI edits, local recovery acknowledgments, shared Session mutations, undo, package snapshots, and native Save must agree on who owns accepted state. Two apps independently opening the same package through a document framework do not prove this agreement. A UI experiment should keep this problem visible without pretending to resolve ADR 0004 by changing a view framework.

### Long-form semantic editing

The macOS 26-era rich `TextEditor` takes an `AttributedString`, supports attributed selection, custom formatting controls, paragraph styling, and constrained formatting. Apple's sample also demonstrates persistence and transfer/export. This is materially more capable than the earlier plain-string editor. [Apple: Rich text session](https://developer.apple.com/videos/play/wwdc2025/280/), [Building rich SwiftUI text experiences sample](https://developer.apple.com/documentation/swiftui/building-rich-swiftui-text-experiences)

The sample establishes formatted editing and custom attributes, not Folio's durable semantic editing contract. **Unproven here:** identity-preserving paragraph split/merge, structural insertion, overlapping annotation anchors, tracked changes, Notes and Citation relationships, unknown-content round trips, and controlled reconciliation of edits from other views. Do not infer those behaviors from successful bold/italic formatting or use RTFD export as evidence of archival folio completeness.

AppKit exposes the input-method contract explicitly through `NSTextInputClient`, including marked text and replacement ranges. TextKit 2 documents viewport-based layout, international text correctness, and custom layout/rendering examples. These are reasons to retain a controllable AppKit editor candidate, not proof it will be bug-free or require little work. [Apple: setMarkedText](https://developer.apple.com/documentation/appkit/nstextinputclient/setmarkedtext(_:selectedrange:replacementrange:)), [Meet TextKit 2](https://developer.apple.com/videos/play/wwdc2021/10061/)

**Folio inference:** Chinese/Japanese composition, combining characters, right-to-left text, selection after structural changes, and undo grouping must be tested against the semantic model in every candidate. A bridge that replaces an entire text value on each model notification could disrupt transient editing state; that is an implementation hazard to test, not a documented universal SwiftUI defect. Layout of an editable Manuscript must also be assessed separately from publication composition and Rendition generation.

### Windows, commands, focus, and keyboard work

SwiftUI has explicit Mac window scenes and controls for placement, sizing, styles, and restoration behavior. Independent windows are not by themselves an argument against it. [Apple: Tailor macOS windows](https://developer.apple.com/videos/play/wwdc2024/10148/), [Work with windows](https://developer.apple.com/videos/play/wwdc2024/10149/)

Commands can populate the native menu bar; `FocusedValue` and scene-scoped values support contextual command state. Focus APIs identify and move keyboard focus. These are documented mechanisms for desktop behavior, not merely touch-oriented controls. [Apple: Menu bar customization](https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui), [Focus](https://developer.apple.com/documentation/swiftui/focus)

**Folio inference:** two Work windows, an inspector, a source search field, and a text editor create distinct command targets. Verify menu enablement, keyboard shortcuts, Find, Undo, and selection-dependent actions when focus moves between those surfaces. An AppKit responder and SwiftUI focused value must describe the same effective target in a hybrid; a visible correct menu is insufficient if its action reaches the wrong Work.

### Research tables, hierarchy, and transfer

SwiftUI `Table` supports selection, sorting, and customizable columns; `OutlineGroup` constructs disclosure UI from identified tree data. This is a credible basis for a Source Library browser and Manuscript outline. It does not establish that every desired inline edit, drag insertion indicator, or expansion-restoration rule is already supplied. [Apple: Table](https://developer.apple.com/documentation/swiftui/table), [OutlineGroup](https://developer.apple.com/documentation/swiftui/outlinegroup)

SwiftUI supports drag and drop through `Transferable` or item-provider interfaces, including transfer between applications. Custom representations are an appropriate mechanism to investigate for Source and Citation payloads. Correct identity, provenance, copy-versus-move behavior, and import permissions remain Folio responsibilities. [Apple: Drag and drop](https://developer.apple.com/documentation/swiftui/drag-and-drop), [Making a view into a drag source](https://developer.apple.com/documentation/swiftui/making-a-view-into-a-drag-source)

### Accessibility and performance

Apple directs developers to test with VoiceOver, Voice Control, and Switch Control, and specifically discusses accessibility when wrapping AppKit controls. Standard controls provide a foundation; custom semantic objects and mixed view hierarchies still require intentional labels, structure, and actions. [Apple: Accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)

Apple documents SwiftUI scheduling and scrolling improvements in the 26 generation, alongside Instruments support for long view updates, platform updates, and their causes. This is positive evidence of investment and diagnostic capability. Apple's general performance improvements cannot be converted into a Folio throughput prediction or an AppKit comparison without measurements. [Apple: What's new in SwiftUI, WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/), [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/)

**Folio inference:** stable identities, narrow observation, off-main-thread expensive work, and bounded materialization will matter regardless of shell. Measure long Manuscripts and large Source Libraries while editing, filtering, scrolling, and saving simultaneously. A fast empty shell or smooth short sample is weak evidence for this workload.

## Stability evidence and its limits

Apple's macOS 26 release notes record the following fixes. These are **resolved in the named release notes**, not claims of currently open failures:

| Area | Official issue | Why retain a regression scenario |
|---|---|---|
| Multiple TextEditors | Invalid undo stack fixed: 83650197 / FB9662463 | Switch editor focus repeatedly, then undo/redo in each context. |
| Dynamic menus | Stale Menu content fixed: 106878937 | Change active selection/window and immediately invoke a menu command. |
| Pointer interaction | Overlay/onHover hit-testing fixed: 108560020 | Verify editor overlays do not intercept intended text interaction. |
| Sidebar hierarchy | Unexpected collapsible Sections fixed: 115797465 | Verify intended hierarchy behavior and keyboard disclosure. |
| AppKit text ranges | NSTextRange issue fixed: 138067979 | AppKit/TextKit comparison needs regression checks too. |

Source: [Apple: macOS 26 release notes](https://developer.apple.com/go/?id=macos-26-rn). These entries were checked against the official notes; no local reproductions were attempted.

The same notes say some SwiftUI buttons on macOS no longer use NSButton (139105246). **Inference:** depending on undocumented backing-view types is a poor escape strategy; prefer public hosting/representable APIs. Historical bugs show useful test targets and active maintenance. They do not establish population-level instability, an unresolved defect count, or comparative crash rates. This review does not claim an exhaustive open-issue inventory. Absence from a later release note is not proof of reliability. [Apple: macOS 26 release notes](https://developer.apple.com/go/?id=macos-26-rn)

Apple also identifies production SwiftUI components inside Logic Pro (Quantec Room Simulator and Beat Breaker) and Xcode’s Coding Assistant. This is stronger evidence than a sample that SwiftUI can serve demanding professional applications, while establishing component adoption rather than an entirely SwiftUI workstation. [Apple: Use SwiftUI with AppKit and UIKit](https://developer.apple.com/videos/play/wwdc2026/272/)

## Four architectures worth distinguishing

| Candidate | Document/shell ownership | Editor | Research assessment |
|---|---|---|---|
| Swift + AppKit | NSDocument and AppKit controllers | AppKit/TextKit | Clearest continuity with current native contracts and storyboard workflow; still requires language and behavior validation. |
| AppKit hosting SwiftUI components | AppKit retains lifecycle and command ownership | AppKit; SwiftUI inspectors/settings/catalog components | Best bounded adoption hypothesis; keeps the highest-risk editing/lifecycle seams explicit. |
| SwiftUI shell hosting an AppKit editor | SwiftUI scenes/commands, deliberately chosen document adapter | AppKit via public representable | Credible contender; focus, undo, layout, and document ownership cross-framework boundaries need proof. |
| Pure SwiftUI | SwiftUI document/scenes/commands | Attributed TextEditor | Simplest framework vocabulary, largest unproven semantic-editor and lifecycle surface for Folio. |

These rankings are engineering judgments from the requirements above. `NSHostingView` explicitly supports SwiftUI within AppKit and coordinates layout/events; `NSViewRepresentable` supports AppKit views within SwiftUI. Neither direction requires wholesale adoption. Apple's WWDC26 session continues to promote incremental integration, including entire SwiftUI scenes in existing architecture; newer convenience APIs require separate availability checks. [Apple: NSHostingView](https://developer.apple.com/documentation/swiftui/nshostingview), [Integrating AppKit](https://developer.apple.com/tutorials/app-dev-training/integrating-appkit), [Use SwiftUI with AppKit and UIKit](https://developer.apple.com/videos/play/wwdc2026/272/)

## Proposed evidence for a later experiment

This is a proposed evaluation protocol, not authorization to implement it or a new architecture contract. Reuse one semantic fixture and command model across candidates so the UI comparison does not hide changes to Work semantics. Begin with the current deployment baseline; report any next-generation SDK/OS arm separately.

1. **Preservation:** edit, save, close, reopen, undo, and redo without losing semantic identities, Notes, Citations, annotations, or unknown vocabulary payloads. Include failed saves and canceled closes. A single accepted edit that cannot be recovered is a hard failure.
2. **Input:** complete Chinese and Japanese IME composition, mixed right-to-left/left-to-right text, combining characters, emoji, multiline paste, and structural edits. No lost input, duplicate commits, displaced selection, or broken undo grouping.
3. **Desktop routing:** operate two Work windows and inspectors entirely by keyboard; verify every command targets the correct selection and Work. Exercise Find, menus, contextual menus, focus restoration, and repeated window close/reopen.
4. **Research loop:** sort/filter a large Source Library, maintain stable selection and outline expansion, transfer a Source to Write, insert a Citation, and return to its Source Record without losing context. Verify payload semantics independently of drag appearance.
5. **Lifecycle:** distinguish ordinary document Save/Auto Save/Revert/Versions from shared Session recovery. For a shell-only experiment, mark cross-process recovery as untested. A later shared-authority claim additionally requires stale-request, disconnect, app-exit, and recovery tests against ADR 0004.
6. **Accessibility:** use VoiceOver and keyboard navigation through editor, Source table, outline, inspector, and dialogs. Confirm meaningful semantic names, reading order, selection announcements, and actionable controls across framework boundaries.
7. **Scale:** use an agreed small/representative/stress fixture set; provisional stress inputs could be a million-character Manuscript and 100,000 Source Records. Record hardware, OS/SDK build, fixture size, memory, typing latency, filter latency, save duration, and hangs. Agree numeric budgets before implementation; compare candidates on identical work. These sizes are proposed test inputs, not claimed supported limits.
8. **Maintenance:** record public adapters and OS-specific workarounds needed. A candidate that passes only through undocumented view introspection should not count as passing the intended public-API design.

The useful result is a per-workflow decision: where SwiftUI reduces implementation burden while preserving behavior, where AppKit remains necessary, and which uncertainties belong to shared persistence rather than the UI framework. Public sources make the hybrid options credible. Only representative runtime evidence can settle Folio's stability question.
