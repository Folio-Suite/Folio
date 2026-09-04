# macOS suite language and integration architecture for Folio

**Research date:** 2026-09-03
**Scope:** Current architectural evidence for a componentized suite of native macOS document applications, with AppKit, Objective-C and Swift, shared code and data, scripting, Help, automation, plug-ins, and direct/App Store distribution.
**Source policy:** Primary sources only. Apple’s archived documentation is labeled where used; it remains useful evidence for still-present Cocoa mechanisms, but is not treated as a current product commitment.

## Executive finding

Folio’s **AppKit-first, desktop-workstation** premise is well supported. AppKit still supplies the mechanisms that make a large native document application coherent: document controllers, window controllers, responder-chain command routing, menu validation, per-document undo, Services, pasteboards, accessibility, and mature text/view infrastructure. None of that implies SwiftUI, and none of it requires that most implementation code be Objective-C.

The evidence supports a **mixed architecture**, but with a narrower Objective-C role than “the suite’s implementation language”:

- Use AppKit throughout the workstation UI.
- Define scripting-visible model objects, selectors, Cocoa Bindings/KVC/KVO surfaces, responder-chain commands, and long-lived framework/XPC interfaces in an intentionally Objective-C-compatible form.
- Implement semantic document logic, parsers, validation, publication pipelines, concurrency, and other type-rich internals in Swift where it helps.
- Keep durable on-disk and cross-process contracts language-neutral and versioned. Neither Objective-C objects nor Swift types should be the canonical Work format.
- Embed private frameworks in each application by default. Do **not** initially install one suite framework in `/Library/Frameworks`; that turns ordinary app updates into coordinated system installation and ABI migration.
- Make direct Developer ID distribution the primary full-capability channel if Folio truly needs broad automation, installed Automator actions, helpers, or shared machine-level components. Maintain an explicitly reduced, sandbox-compatible App Store product profile rather than assuming one build can express every integration.

The resulting seam is best described as **Objective-C-compatible Cocoa surface, mixed-language implementation, language-neutral suite protocols**. Objective-C is constitutionally important, but current evidence does not justify making all Folio code Objective-C.

## 1. AppKit and Objective-C are separate decisions

AppKit’s architecture is inherently dynamic, but Swift can participate in it through Objective-C interoperability. Choosing AppKit therefore answers the UI-framework question, not the language question.

Apple’s archived Application Architecture Overview ties document architecture, scripting, and undo together conceptually. `NSDocument`, `NSWindowController`, and `NSDocumentController` form the document architecture; model/view/controller organization supports all three mechanisms. [Apple, *Application Architecture Overview* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AppArchitecture/AppArchitecture.html) [Apple, *Document Architecture* (archived and superseded)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AppArchitecture/Concepts/DocumentArchitecture.html)

The responder chain is a material asset for Folio. AppKit routes action messages through views, windows, window controllers, documents, the application, and the document controller; nil-target menu items and toolbar items use this mechanism for automatic targeting and validation. Services eligibility also follows the responder chain. This is precisely the kind of context-sensitive command system a multi-window editor needs. [Apple, *Event Architecture* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html)

AppKit integrates undo with this architecture. Each `NSDocument` has an undo manager by default; undo flows through responders, and document edited state follows undo-manager notifications. Apple explicitly recommends that persistent model mutations be undoable in the model layer. [Apple, *Using Undo in AppKit-Based Applications* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/AppKitUndo.html)

These benefits accrue equally to an AppKit application written in Swift or Objective-C. Objective-C becomes materially simpler when Folio wants to expose and manipulate the dynamic shape directly:

- selectors and optional protocol methods as ordinary language concepts;
- KVC-compliant key paths and KVO notifications without exposure annotations or bridging constraints;
- Cocoa Bindings, whose contract is KVC/KVO-based;
- Cocoa Scripting, whose object-model dispatch is KVC- and selector-oriented;
- runtime class/protocol lookup and dynamically loaded bundle entry points;
- headers that form a stable, inspectable interface consumable by Objective-C, Swift, and Objective-C++.

Cocoa Bindings still exists in AppKit and depends on KVC, KVO, and model compliance with key-value coding conventions. It can synchronize changes caused by either UI editing or scripted Apple events. This is evidence that Objective-C-shaped model/controller surfaces fit the older framework exceptionally well; it is **not** evidence that Folio should use Bindings pervasively. Bindings trade explicit control and static checking for declarative wiring, so they should be evaluated per inspector/list/form rather than made foundational. [Apple, *What Are Cocoa Bindings?* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaBindings/Concepts/WhatAreBindings.html)

**Conclusion:** choose AppKit confidently. Use Objective-C where the API is intentionally dynamic or public across modules. Do not infer that complex AppKit UI is intrinsically harder in Swift; that claim lacks first-party evidence and depends heavily on team fluency and design.

## 2. What Swift interoperability changes

Swift interoperates deeply with Objective-C, but an Objective-C-visible API is a restricted subset of Swift’s type system. In practice, `@objc` interfaces cannot freely expose Swift-only value types, enums with associated values, generic APIs, actors, many protocol features, or arbitrary async/concurrency semantics. The official Swift evolution proposal for implementing Objective-C declarations in Swift explicitly notes that some members cannot be implemented through an `@objc @implementation` extension because Objective-C interop does not support their features. [Swift Evolution, SE-0436](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0436-objc-implementation.md)

That restriction is useful at Folio’s enduring seams: it forces APIs toward objects, primitives, Foundation value classes, completion handlers, errors, and stable selectors. It is costly if imposed on all internal semantic modeling, where Swift enums, structs, generics, protocols, actors, and `Sendable` checking are valuable.

Swift ABI stability on Apple platforms means current and future Swift-compiled binaries can use the OS Swift runtime. Module stability and library evolution address separately compiled libraries. Library evolution is opt-in (`-enable-library-evolution`) and preserves particular binary-compatible changes through resilient types; it does not make arbitrary API changes safe. Swift’s own documentation describes resilience domains as modules version-locked together, while SE-0260 says libraries shipped with their clients normally do not need library-evolution mode. [Swift.org, *ABI Stability and More*](https://www.swift.org/blog/abi-stability-and-more/) [Swift Evolution, SE-0260](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0260-library-evolution.md) [Swift compiler, *Library Evolution*](https://github.com/swiftlang/swift/blob/main/docs/LibraryEvolution.rst)

Therefore:

- Swift is viable inside embedded Folio frameworks compiled and shipped with each app.
- Swift is also viable in a separately installed binary framework, but Folio would have to opt into library evolution, ship textual module interfaces for Swift clients, maintain ABI/API discipline, and coordinate deployment carefully.
- An Objective-C public header remains a simpler conservative ABI surface, but ABI compatibility still requires disciplined evolution; Objective-C does not make binary compatibility automatic.
- Cross-process interfaces should use explicit `@objc` protocols and constrained Foundation/NSSecureCoding payloads, or lower-level serialized messages. Swift implementation types should not leak into them.

## 3. Sharing code and data across standalone applications

### Embedded frameworks should be the default

Apple’s current embedding technical note says apps using frameworks need to embed them in their application bundle; an application target embeds all dependent frameworks. Apple’s archived framework guide also states that embedding guarantees that an application has the correct version. [Apple, TN2435, *Embedding Frameworks In An App*](https://developer.apple.com/library/archive/technotes/tn2435/_index.html)

Apple’s older framework guide does document `/Library/Frameworks` as a location for a framework shared by a suite, installed with a package. But that guidance was last updated in 2013, while the current distribution guidance emphasizes embedding and signed product containers. Treat system-installed suite frameworks as supported Mach-O behavior, not as Apple’s default contemporary app architecture. [Apple, *Installing Your Framework* (archived, 2013)](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/InstallingFrameworks.html)

A single `/Library/Frameworks/FolioKit.framework` would create these consequences:

- Apps fail at launch if the required framework is absent or incompatible.
- Updating one app may update shared code used by older independently installed apps.
- Uninstallation and rollback require reference/version management.
- Installation needs a privileged signed `.pkg`, rather than drag-copying independent `.app` bundles.
- Library binaries and installers must be signed and notarized, and every dependent app’s loader path/version expectations must be maintained.
- App Store delivery is a poor match because App Store apps are self-contained and sandboxed; a separately installed machine-wide dependency cannot be assumed.

The modest disk duplication of embedding is usually worth version isolation. The dynamic loader can still share identical read-only pages where applicable; the architectural decision should not be based on an old “one physical copy” optimization.

**Recommendation:** produce shared source/framework targets, then embed and sign a version-matched copy in every app. Revisit system installation only if measured size, a truly shared in-process service, or third-party developer SDK requirements make it necessary.

### Share user data, not live object graphs

App groups allow multiple apps from one team to access shared containers and certain IPC mechanisms. Apple’s current documentation says macOS app groups can connect sandboxed and nonsandboxed apps; macOS 15+ app group containers also gain SIP-backed protection. [Apple, *Configuring app groups*](https://developer.apple.com/documentation/xcode/configuring-app-groups) [Apple, *Accessing app group containers*](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)

That is suitable for suite preferences, caches, indices, registries, and coordination metadata. The authoritative Work should remain a user-owned document package wherever the user places it, with file coordination and explicit access considered separately. A package gives Folio a single document identity while internally containing structured content, assets, indexes, and provenance. Shared-container storage should not make the Work invisible or vendor-captive by accident.

Simultaneous editing by multiple apps is a data-consistency problem, not solved by using a shared framework or app group. Folio needs an explicit ownership/coordination model: for example, one writer with read-only peers; a broker process; or transactional storage with conflict semantics.

### Cross-process mechanisms have distinct roles

- **XPC:** `NSXPCConnection` is a bidirectional channel whose exported and remote interfaces are described by `NSXPCInterface`. It can connect to an app-bundled service, an endpoint, or a named launchd service. Use it for reliable suite services or isolation, with narrow versioned protocols and secure-coded allowed classes. App-bundled XPC services are private to their host; a suite-wide broker is a different deployment/signing proposition. [Apple, `NSXPCConnection`](https://developer.apple.com/documentation/foundation/nsxpcconnection) [Apple, `NSSecureCoding`](https://developer.apple.com/documentation/foundation/nssecurecoding) [Apple, *Creating XPC Services* (archived)](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html)
- **Apple events:** best for semantic, user-visible automation between independently running apps. They are durable but permission- and sandbox-sensitive.
- **Services:** best for selection-oriented “send/transform/return” actions available in other apps. They exchange pasteboard data and integrate through the responder chain. [Apple, *Services Overview* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/overview.html)
- **Pasteboards and drag/drop:** best for user-mediated transfer, with public types plus Folio semantic representations.
- **Files/document packages:** best durable interchange and handoff surface.
- **URL schemes/universal links:** useful for navigation and coarse commands, not a rich object protocol.

## 4. Distribution architecture

### Direct distribution

Apple explicitly supports direct distribution with Developer ID. Current notarization requires valid signatures for executables, Developer ID identities, hardened runtime, secure timestamps, and other signing hygiene. Notarization scans and tickets software but is not App Review. Apps, disk images, and flat installer packages can be notarized. [Apple, *Notarizing macOS software before distribution*](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

Apple recommends `.pkg` when a product has multiple components, must copy items to specific locations, or needs installation logic. A package for direct distribution uses a Developer ID Installer identity. [Apple, *Packaging Mac software for distribution*](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

Direct distribution therefore fits a Folio suite that installs apps together, registers Automator actions, installs command-line tools or launch services, or someday installs a machine-level framework. It also makes Folio responsible for secure updates, rollback, component receipts/uninstallation, billing, and support. Apple’s distribution comparison explicitly assigns updates to the developer outside the Store. [Apple, *Distributing software on macOS*](https://developer.apple.com/macos/distribution/)

The hardened runtime should be treated as mandatory even outside the Store. Runtime exceptions should be minimized. Frameworks and in-process plug-ins inherit host entitlements. Loading arbitrary third-party code may require disabling library validation, which weakens a protection and expands the host’s entitlement burden. [Apple, *Hardened Runtime*](https://developer.apple.com/documentation/security/hardened-runtime) [Apple, *Notarizing macOS software before distribution*, “Notarize plug-ins”](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

### Mac App Store

Apple currently requires App Sandbox for Mac App Store distribution. Sandboxing constrains arbitrary filesystem reach and sending Apple events to other applications. Receiving Apple events and responding to them remains possible; outbound automation requires target-specific scripting entitlements or temporary exceptions, and broad temporary exceptions may be rejected. [Apple, *App Sandbox*](https://developer.apple.com/documentation/security/app-sandbox) [Apple, QA1888, *Sandboxing and Automation in OS X* (archived)](https://developer.apple.com/library/archive/qa/qa1888/_index.html)

An App Store edition can still be a serious AppKit document app, expose a scripting dictionary, receive automation, use user-selected files/security-scoped access, share app-group data with sibling signed apps, and offer App Intents. What it cannot safely promise is arbitrary control of unrelated applications, installation into system locations, or an unrestricted in-process plug-in ecosystem.

**Recommendation:** maintain shared product code but explicitly design two integration manifests:

1. **Direct edition:** notarized hardened runtime, nonsandboxed only where justified, signed package if installing multiple components, automation integrations enabled deliberately.
2. **App Store edition:** sandboxed, self-contained, embedded frameworks, user-selected document access, App Intents and inbound scripting, with unsupported integrations omitted rather than hidden behind fragile exceptions.

Do not let direct distribution become an excuse to skip sandbox-like internal boundaries. Use XPC isolation, least privilege, code-signing requirements, secure coding, and user consent regardless of channel.

## 5. Integrated Help

Apple Help remains present in current AppKit: `NSHelpManager.registerBooks(in:)` registers additional help books, while books in the main bundle are registered automatically when accessed. [Apple, `NSHelpManager.registerBooks(in:)`](https://developer.apple.com/documentation/appkit/nshelpmanager/registerbooks%28in%3A%29)

The detailed authoring guide is archived (2012-era). It describes HTML/XHTML help books, bundle registration through `CFBundleHelpBookFolder` and `CFBundleHelpBookName`, Help Viewer search indexes, anchors, localization, and contextual opening through `NSHelpManager`. It strongly recommends embedding the help book in the application; third-party use of global Help directories is unsupported. [Apple, *Help Book Registration* (archived)](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/ProvidingUserAssitAppleHelp/registering_help/registering_help.html) [Apple, *Apple Help Concepts* (archived)](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/ProvidingUserAssitAppleHelp/user_help_concepts/apple_help_concepts.html)

The APIs’ continued presence supports integrated Help, but Apple’s current first-party authoring/tooling story is thin. Before committing to Help Viewer as the sole help presentation, Folio should test current indexing, localization, search behavior, accessibility, and packaging on its deployment OS versions. A sensible architecture generates each app’s embedded Help Book from the same versioned documentation sources used for web help, while preserving stable contextual anchor identifiers.

## 6. AppleScript, Cocoa Scripting, OSA, and `osascript`

### Making Folio scriptable

Cocoa Scripting converts incoming Apple events into `NSScriptCommand` objects. It relies heavily on KVC to read and mutate model keys. An application’s `.sdef` scripting dictionary defines its suites, classes, properties, elements, commands, parameters, enumerations, and access groups. [Apple, *Scripting* (archived)](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AppArchitecture/Concepts/Scripting.html) [Apple, *About Scripting Terminology* (archived)](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AboutScriptingTerminology.html)

This is the strongest argument for an Objective-C-compatible **automation façade**. Script-visible objects should have durable IDs, intentional KVC keys, explicit element relationships, and command handlers independent of transient UI/model implementation objects. Swift can implement this façade, but it must adopt Objective-C-compatible classes and selectors, which removes much of Swift’s internal modeling advantage at that boundary.

The scripting dictionary should be suite-wide in vocabulary but app-specific in ownership. Stable four-character Apple event codes and stable semantic IDs matter more than the implementation language. Folio should include access groups in its SDEF so sandboxed sibling/third-party apps can request narrow capabilities rather than temporary broad exceptions.

### Running scripts

- `NSUserAppleScriptTask` is Apple’s current Foundation API for running user-supplied AppleScript. In a sandboxed app scripts must reside in the application scripts directory; they execute outside the app sandbox, and the app may read but not write that directory. It is not intended for scripts bundled into the app. [Apple, `NSUserAppleScriptTask`](https://developer.apple.com/documentation/foundation/nsuserapplescripttask)
- `NSAppleScript` and OSAKit are lower-level in-process compilation/execution surfaces; their presence does not bypass Apple-event consent or sandbox rules. They should not be the primary extension/security boundary.
- `/usr/bin/osascript` is a command-line host for OSA languages. It is useful to users, shell automation, tests, and installer scripts, but Folio need not invoke it internally merely to be scriptable.

Expose automation first; embed script execution only for concrete workflows. A user Script menu backed by `NSUserAppleScriptTask` is plausible. Built-in behaviors should call Folio’s command layer directly rather than ship as opaque AppleScripts.

## 7. Automator, Shortcuts, Services, and command-line tools

Third-party Automator actions remain supported by current Apple documentation. The Automator framework develops actions and runs workflows; Automator loads action bundles from `/System/Library/Automator`, `/Library/Automator`, and `~/Library/Automator`. [Apple, *Automator*](https://developer.apple.com/documentation/automator)

Archived sandbox guidance says actions may also be embedded at `Contents/Library/Automator` in an app bundle. Standalone actions are plug-ins loaded by Automator and inherit practical restrictions from their host/execution context. [Apple, QA1888 (archived)](https://developer.apple.com/library/archive/qa/qa1888/_index.html)

However, “API still documented” is not evidence of strong future investment. Current Apple platform investment is visibly in App Intents: Apple says intents make actions/data available to Shortcuts, Siri, Spotlight, widgets, and Apple Intelligence; the framework continues to receive 2026 updates. App Intents are Swift protocol/value-type APIs and will require a Swift module even if Folio’s main AppKit surface is Objective-C. [Apple, *App Intents*](https://developer.apple.com/documentation/appintents) [Apple, *App Intents updates*](https://developer.apple.com/documentation/Updates/AppIntents)

Recommended automation portfolio:

1. **Canonical command/service layer:** internal, UI-independent operations with stable semantic inputs/results.
2. **AppleScript dictionary:** rich object manipulation and professional desktop automation.
3. **App Intents:** curated, task-oriented Shortcuts/Spotlight/system actions; implemented in Swift.
4. **Services:** selection-based transforms and import/export.
5. **Command-line tool:** batch publishing, validation, conversion, and CI; communicate with documents/services through stable file or IPC contracts.
6. **URL links:** navigation to Works, units, sources, and commands requiring UI.
7. **Automator actions:** a compatibility/pro-user layer built only for operations that are meaningfully composable as typed workflow steps.

Automator should therefore be supported, but not serve as Folio’s core automation abstraction. Direct distribution with a signed installer is the cleanest way to install standalone actions; the App Store edition should favor App Intents and embedded/user-installed workflows.

## 8. Plug-ins and dynamic bundles

Foundation still exposes `Bundle.load()` for dynamically loading executable code such as a plug-in or framework, and bundle structures have built-in plug-in directories. [Apple, `Bundle.load()`](https://developer.apple.com/documentation/foundation/bundle/load%28%29) [Apple, `Bundle`](https://developer.apple.com/documentation/foundation/bundle)

But code loading is now governed by code signing, notarization, hardened runtime, and library validation. Apple says quarantined plug-ins must be notarized; in-process plug-ins inherit host entitlements; and arbitrary plug-ins/frameworks may require the host’s Disable Library Validation entitlement. This makes classic arbitrary in-process bundles a costly primary extension architecture. [Apple, *Notarizing macOS software before distribution*](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) [Apple, *Hardened Runtime*](https://developer.apple.com/documentation/security/hardened-runtime)

Prefer, in order:

- declarative themes/templates and language-neutral document transformations;
- scripts and command-line filters with explicit file/message contracts;
- App Intents and Services for system integration;
- out-of-process extensions/XPC with authenticated clients and narrow protocols;
- same-team, signed, embedded in-process bundles where performance or UI embedding truly demands them;
- arbitrary third-party in-process plug-ins only after a security and compatibility design exists.

Objective-C runtime discovery makes classic plug-ins ergonomic; it does not solve their security, crash-isolation, ABI, or update problems.

## 9. Decision matrix

Scores: **strong**, **workable**, **weak** for Folio’s stated needs, assuming experienced developers and current macOS.

| Architecture | Dynamic AppKit / scripting fit | Internal type safety / concurrency | Independently versioned binary seams | App Intents | Deployment simplicity | Overall |
|---|---|---|---|---|---|---|
| Objective-C + AppKit throughout | **Strong** | **Weak–workable** | **Strong** with disciplined headers/ABI | **Weak**; Swift bridge target required | **Strong** when embedded; system frameworks still complex | Viable, but sacrifices Swift where it is strongest without solving deployment itself |
| Swift + AppKit throughout, ad hoc `@objc` exposure | **Workable** | **Strong** | **Workable** with library evolution and careful API design | **Strong** | **Strong** when embedded | Viable, but risks letting accidental Swift types/async assumptions reach durable Cocoa seams |
| Objective-C-compatible façade + Swift internals + AppKit | **Strong** | **Strong** | **Strong–workable** depending on whether the public seam is Obj-C or resilient Swift | **Strong** | **Strong** with embedded frameworks | **Recommended**; boundary discipline is the cost |
| SwiftUI-first Swift application | **Weak** for the stated mature workstation interaction model | **Strong** | **Workable** | **Strong** | **Strong** | Poor fit for current intent; can still supply isolated views where useful |
| Shared `/Library/Frameworks` suite runtime | Language-independent | Language-independent | Demands strongest ABI/version discipline | Neutral | **Weak**: installer, coordinated updates, launch dependency | Defer unless a demonstrated requirement outweighs operational risk |
| Embedded framework copy per app | Language-independent | Language-independent | Apps are version-isolated | Neutral | **Strong** and App Store compatible | **Recommended default** |

## 10. Recommended staged posture for Folio

### Stage 0: architectural rules before implementation

1. **AppKit is the workstation UI framework.** SwiftUI may appear in bounded components, not dictate the application architecture.
2. **The Work format is language-neutral, documented, versioned, and migration-capable.** Never archive arbitrary live Swift/Objective-C object graphs as the canonical document.
3. **Every durable seam has an owner and version policy:** Work schema, command vocabulary, SDEF terminology/codes, XPC protocols, pasteboard types, URL syntax, plug-in protocol, and CLI contract.
4. **Private frameworks are embedded per application.** Build shared sources once; ship compatible binaries with each app.
5. **Automation commands are model commands, not menu simulation.** Menus, AppleScript, App Intents, Services, CLI, and Automator adapt to the same operations.

### Stage 1: first production application

- Write the AppKit shell in either language according to developer fluency, but expose all responder actions, document/window coordination, scripting objects, and binding surfaces through Objective-C-compatible declarations.
- Use Swift for the semantic Work implementation and transformations if its type system/concurrency help; wrap only the boundary, not every internal type.
- Add a small Objective-C façade framework (or Objective-C declarations implemented in Swift where supported) containing stable Cocoa-facing protocols, IDs, errors, and commands.
- Add App Intents in a separate Swift target backed by the command layer.
- Embed one Help Book generated from common documentation sources; test current Help Viewer behavior rather than assuming archived tooling instructions remain smooth.
- Sign with hardened runtime from the beginning and exercise both direct and sandboxed configurations early.

### Stage 2: second application and suite coordination

- Embed the same framework source at compatible versions in the second app.
- Use the document package and app-group container for durable/shared data as appropriate.
- Introduce XPC only for an actual owner/service/isolation requirement; use an Objective-C protocol plus secure, versioned values.
- Publish a shared SDEF vocabulary with explicit app ownership and scripting access groups.
- Validate concurrent access and upgrade/migration behavior before considering a central broker.

### Stage 3: professional integrations

- Ship direct distribution first for the complete integration profile, using a signed/notarized `.pkg` only when installation outside `.app` bundles is genuinely required.
- Add CLI, Services, user scripts, curated App Intents, and contextual Help.
- Add Automator actions as adapters to stable commands, not as the sole workflow API.
- Design third-party extensions out of process or declaratively before considering arbitrary in-process code.
- Produce a separate sandbox capability matrix before App Store submission.

### Trigger for reconsidering a system-installed shared framework

Reconsider `/Library/Frameworks` only if at least one is demonstrated:

- independently installed third-party clients must link the Folio SDK;
- multiple suite apps require one exact, machine-wide in-process implementation and cannot use IPC;
- embedded duplication has a measured, material operational cost;
- suite-wide hotfixing of one binary is worth coordinated rollback and compatibility machinery.

Even then, compare a signed launchd/XPC service with a language-neutral protocol. It frequently centralizes behavior without forcing every app to load the same binary into its process.

## 11. Claims that remain uncertain

- Apple provides current API references for Automator and `NSHelpManager`, but most detailed guidance is archived. Their APIs are supported; their strategic longevity and tooling quality are not documented commitments.
- Apple’s archived framework guide explicitly describes suite frameworks in `/Library/Frameworks`, but current first-party guidance favors embedding. No current Apple source found says third-party `/Library/Frameworks` installation is forbidden; neither does current guidance recommend it as the ordinary suite architecture.
- No primary source establishes that complex AppKit UI is categorically easier in Objective-C than Swift. The demonstrated distinction is dynamic API ergonomics and interface representability.
- No primary source found establishes Microsoft Office’s current internal framework installation layout or validates it as a model for third parties. Folio should not base its architecture on inferred Office packaging.
- Mac App Store review outcomes for particular automation entitlements are case-specific. Archived Apple guidance warns broad temporary Apple-event exceptions are likely to be rejected; Folio must validate its exact entitlement set with current App Review requirements.

## Bottom line

The intuition is directionally right but needs one correction: **Objective-C is a strong surface language for Folio’s Cocoa constitution, not necessarily the best universal implementation language.** AppKit should be foundational. Objective-C-compatible boundaries should be designed deliberately around scripting, responders, bindings, runtime discovery, XPC, and long-lived binary contracts. Swift should be welcomed behind those boundaries and is required for the modern App Intents surface.

Likewise, a traditional installer can unlock the full suite, but “traditional” need not mean one mutable framework in `/Library/Frameworks`. The safer contemporary form is a signed/notarized suite installer whose apps remain self-contained, coordinate through documents, app groups, Apple events, and narrow services, and share source/API design rather than one fragile installed binary.
