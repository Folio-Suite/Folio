<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Modular frameworks, sandboxing, and App Store distribution

**Research date:** 2026-09-08

**Scope:** Folio's proposed framework structure and the possibility that installing Research adds capabilities and shared UI to an independently useful Write, across direct and Mac App Store distribution.

**Source policy:** Primary Apple documentation, public Apple source code, installed SDK declarations, and identified Apple Developer Technical Support answers. Archived guidance and architectural inferences are labeled. This is research, not a change to the approved distribution or Work Session decisions.

## Executive finding

**Sandboxing does not rule out Folio's modular vision, shared UI, or applications enhancing one another.** Apple now documents a particularly relevant mechanism: an application can publish custom extension points, and a separately distributed application can contain an extension that supplies another application's functionality. Apple explicitly describes developing an extension for a host on the App Store. The extension executes in a separate process through ExtensionFoundation. [Building an app extension to support a host app](https://developer.apple.com/documentation/extensionfoundation/building-an-app-extension-to-support-a-host-app)

ExtensionKit can display that extension's interface inside the host. This is a documented route to a Research-supplied picker or inspector inside Write, without loading Research's framework into Write's address space. It is also a real process boundary: Write receives an opaque hosted interface and communicates through an explicit protocol. [Including extension-based UI in your interface](https://developer.apple.com/documentation/extensionkit/including-extension-based-ui-in-your-interface)

The decisive qualification is that **framework organization, code installation, process authority, and distribution policy are different decisions**. A framework can define reusable Objective-C APIs and AppKit UI regardless of whether each application embeds its own copy or one component uses it behind an XPC boundary. The literally named `SharedFrameworks` directory exists, but its name does not grant cross-application access or establish an App Review outcome. [Xcode build phases](https://developer.apple.com/documentation/xcode/customizing-the-build-phases-of-a-target), [Bundle.sharedFrameworksURL](https://developer.apple.com/documentation/foundation/bundle/sharedframeworksurl)

**Recommendation:** retain App Store compatibility as a serious candidate for the full modular concept. Prefer self-contained applications, embedded framework copies, versioned service contracts, and a bounded extension UI proof. Do not make a single externally installed framework binary, or raw loading from another application's bundle, a prerequisite for the architecture. The user's proposed direction gives Write authority over Works and Research authority over Source Libraries, with each domain's persistence module hosted in its own executable; the exact deployment remains to be established.

## 1. The boundaries that must stay distinct

| Boundary | What it decides | What it does not decide |
|---|---|---|
| Source module or internal library | Responsibility, private implementation, build dependencies | Where a running service lives |
| Framework interface | Supported APIs, reusable domain capabilities and possibly UI | Permission to inspect another application's objects or files |
| Embedded framework product | Which code and resources ship with an executable | A shared instance of that framework's objects across processes |
| Process and XPC contract | Authority, messages, isolation, failure, independent versions | Permission to bypass another process's security restrictions |
| Sandbox and entitlements | Resources and operations available to an executable | Acceptance by App Review |
| Distribution package | Installation, updates, ownership, removal | Semantic ownership of the Work |

This table is an architectural decomposition, not an Apple-mandated hierarchy. Folio can retain the proposed FolioKit, WriteKit, ResearchKit, and internal libraries while choosing packaging separately. Apple's framework documentation supports packaging a dynamic library and associated resources together; current Xcode documentation distinguishes public, private, and project headers. [Framework bundle structure, archived](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html), [Xcode headers and build phases](https://developer.apple.com/documentation/xcode/customizing-the-build-phases-of-a-target)

## 2. What `SharedFrameworks` actually establishes

Several arrangements are often conflated:

| Arrangement | Evidence and boundary |
|---|---|
| Each application embeds `FolioKit.framework` in `Contents/Frameworks` | The current documented location for frameworks and dynamic libraries. Applications can ship compatible source interfaces with independently versioned embedded binaries. [Placing content in a bundle](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle) |
| A framework lives in `AnApp.app/Contents/SharedFrameworks` | Current Xcode Copy Files documentation still lists this destination, and Foundation exposes its URL. This establishes a recognized bundle location. It does not create a suite-wide loader, registry, permission grant, or compatibility contract. [Xcode build phases](https://developer.apple.com/documentation/xcode/customizing-the-build-phases-of-a-target), [Bundle.sharedFrameworksURL](https://developer.apple.com/documentation/foundation/bundle/sharedframeworksurl) |
| A framework lives in `/Library/Frameworks` | Apple's archived framework guide describes shared installation for suites and an installer package. This is historical evidence for a direct-distribution arrangement, not current Store permission or a guarantee about modern loader search paths. [Installing your framework, archived 2013](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/InstallingFrameworks.html) |
| Write loads a framework physically inside Research's application bundle | This combines executable access, code-signing compatibility, loader paths, discovery, and independent updates. No source inspected establishes this exact Folio arrangement as both robust and acceptable to App Review. It requires a dedicated proof if desired. |

Apple's public code-signing implementation recognizes `SharedFrameworks` among nested-code directories. The directory is therefore not intrinsically an invalid macOS code-signing layout. Source implementation is evidence about code signing, not a contractual promise of Store acceptance. [Apple Security source, `BundleDiskRep::defaultResourceRules`](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_codesigning/lib/bundlediskrep.cpp)

The archived App Extension Programming Guide warns that selecting the `SharedFramework` copy destination causes App Store rejection. Its surrounding instructions discuss containing applications and their extensions and explicitly mention both iOS and OS X; calling the warning simply “iOS-only” would be inaccurate. It also belongs to an older extension-embedding workflow, so it cannot by itself settle every current macOS arrangement. Current placement guidance still gives us a clear default: `Contents/Frameworks`. [Handling common scenarios, archived](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html), [Current bundle placement](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle)

**Inference for Folio:** the folk wisdom has a sound technical core—shared frameworks and modular code are possible—but the stronger assertion “the directory permits two Store apps to share one installed runtime” remains unproven.

## 3. App Sandbox and runtime code security are separate layers

App Sandbox limits an application's resource access. Hardened Runtime and library validation separately control executable behavior and code loading. Notarization is a distribution security check, distinct from App Review. Choosing direct distribution does not require abandoning sandboxing. [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime), [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

With library validation enabled, a process normally loads code signed by Apple or by the same development team. Folio's own embedded framework modules do not, merely by being modules, require disabling that protection. Entitlements belong to executable processes rather than to the libraries they load; putting a class in ResearchKit does not grant it Research's permissions when it runs inside Write. [Disable Library Validation entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation), [Creating distribution-signed code for the Mac](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac)

Apple DTS explicitly documents `/Applications` as part of App Sandbox's static executable-access allowance, using execution of another installed application's developer tool as its example. It contrasts this with an application at an arbitrary user-chosen location: dynamic file access obtained through a selection dialog does not grant executable access. Thus “sandboxed apps can never execute another app's code” is too broad, while “choosing any external framework makes it loadable” is also wrong. The DTS example proves tool execution, **not** Folio's proposed sibling-framework `dlopen` arrangement. [Running developer tools from a sandboxed app, Apple DTS, February 2024](https://developer.apple.com/forums/thread/746478)

Modern launch and library constraints add another independent control: a signed executable can constrain the code it launches or loads. Passing the sandbox check is not sufficient evidence that every signing, library-validation, or launch constraint also passes. [Applying launch environment and library constraints](https://developer.apple.com/documentation/security/applying-launch-environment-and-library-constraints)

There is a useful middle option between unrestricted direct distribution and the Store: **direct distribution with sandboxed front ends**. Apple DTS identifies temporary exception entitlements and nonsandboxed XPC services as options available to directly distributed sandboxed apps. Those are possible choices for a direct edition, not an assumed route through Store review. [Direct-distribution sandbox options, Apple DTS, March 2025](https://developer.apple.com/forums/thread/776609)

For third-party in-process plug-ins, signing and notarization obligations still apply, and arbitrary signer support may require relaxed library validation. That is a different security commitment from same-team Folio modules or out-of-process extensions. [Notarizing plug-ins](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Library validation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation)

## 4. The strongest documented route to Research enhancing Write

### A separately shipped capability provider

On current macOS, a host can declare a custom extension point that accepts providers outside its own bundle. The newer extension-point API defaults to restricting providers to the host bundle; `Scope(restriction: .none)` removes that restriction on macOS. The extension's containing application supplies its installation package, and the provider implements the interface declared by the host. [Adding support for app extensions](https://developer.apple.com/documentation/extensionfoundation/adding-support-for-app-extensions-to-your-app), [Scope.Restriction.none](https://developer.apple.com/documentation/extensionfoundation/appextensionpoint/scope/restriction/none)

The system registers providers when their containing application is installed and removes registrations when it is uninstalled. Monitoring APIs report changes to the available providers. Crucially, separately shipped extensions begin disabled and require the device owner's approval; the host can present Apple's extension browser inside its settings. “Install Research, then enable its integration” is therefore the supported user journey to test, rather than an unconditional promise of silent activation. [Discovering app extensions](https://developer.apple.com/documentation/extensionfoundation/discovering-app-extensions-from-your-app), [Displaying available app extensions](https://developer.apple.com/documentation/extensionkit/displaying-the-app-extensions-available-to-your-app)

**Proposed Folio use:** Write provides basic Citation editing and formatting on its own. Research contains a provider for library search, Source selection, or richer research inspection. Write discovers an enabled compatible provider and offers the corresponding operation. The exchanged result contains the selected Source Record subset, provenance, and required dependencies already specified in the [Source Library contract](../architecture/source-library-contract.md).

### Two forms of shared UI

1. **Locally embedded UI:** both applications ship the appropriate reusable UI framework. Write's UI calls a Research capability through a service interface when available. UI implementation is shared at build time, while the provider supplies live functionality. This is an architectural proposal that minimizes remote-view integration demands.
2. **Provider-owned UI:** Research's extension supplies a scene that Write embeds using `EXHostViewController`. The host receives activation/deactivation callbacks and can establish scene-specific XPC communication. This permits separately delivered research presentation, with explicit process boundaries. [Including extension-based UI](https://developer.apple.com/documentation/extensionkit/including-extension-based-ui-in-your-interface)

Remote UI does not make Research's live objects into ordinary Write-local objects. Local Objective-C messages, subclass relationships, and direct view ownership remain local; remote operations pass through proxies or serialized messages. Folio can share protocol definitions and primitives in frameworks without pretending this boundary is an in-process inheritance relationship.

The current extension entry-point and scene APIs use Swift and SwiftUI types, while the host view controller is an AppKit controller and XPC supports Objective-C protocols. The inspected Xcode 26.6 SDK includes these APIs within Folio's current macOS 26.5 target. A narrow Swift bridge around existing Objective-C/AppKit facilities is a plausible implementation; adopting extensions does not require rewriting the domain frameworks in Swift. Exactly how reusable AppKit views participate in the remote scene remains part of the UI proof. [AppExtension](https://developer.apple.com/documentation/extensionfoundation/appextension), [PrimitiveAppExtensionScene](https://developer.apple.com/documentation/extensionkit/primitiveappextensionscene), [EXHostViewController](https://developer.apple.com/documentation/extensionkit/exhostviewcontroller), [NSXPCInterface](https://developer.apple.com/documentation/foundation/nsxpcinterface)

### Shared services and data

App Groups expressly support shared containers and IPC between same-team applications, including sandboxed and nonsandboxed macOS applications. Group-qualified Mach service names can permit communication without a global Mach lookup exception. Membership provides access; it does not create the listener or choose which installed executable owns it. [Application Groups entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups), [Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

An embedded `.xpc` service is private to its containing application in Apple's documented XPC-service architecture. A shared named service or an extension process is a different deployment arrangement. Authentication also remains explicit: `NSXPCConnection.setCodeSigningRequirement` can require the peer to satisfy an expected signature before communication proceeds. [Creating XPC services, archived](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html), [Setting a code-signing requirement](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:))

Apple DTS also warns against publishing a named XPC listener directly from a GUI application: arrangements that appear to work when launched by Xcode can fail when launched normally. A shared rendezvous needs an appropriately registered job; the App Group entitlement alone does not create it. This makes ExtensionFoundation's supported discovery and connection path particularly useful for optional capabilities. [XPC and app-to-app communication, Apple DTS](https://developer.apple.com/forums/thread/715338)

## 5. Store policy: neither a universal ban nor blanket approval

The current rules must be read together:

| Rule | Relevant boundary |
|---|---|
| 2.4.5(i–vii) | Sandbox; self-contained Xcode packaging; no shared-location installation or privilege escalation; consent for startup/persistent background execution; Store-managed updates. |
| 2.5.2 | Restricts self-modification and executable delivery that changes functionality. |
| 3.1.1 | Explicitly allows Mac App Store hosts of plug-ins or extensions enabled outside the Store; also regulates feature unlocking. |
| 4.2.3(i) | Each app must be useful without another installed app. |
| 2.3.1 and 4.4 | Integrations must be disclosed and reviewable; extension-specific rules apply. |

[Current App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

The current Developer Program License Agreement, §3.3.1(D), additionally requires the files necessary to execute a Mac Store application to be in its submitted bundle and excludes a collection of independent applications inside one application bundle. An integrated single application with auxiliary components is a different proposition from wrapping all of Folio's independent applications in one Store submission. [Current Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)

**Inference:** useful standalone Write plus an optional, disclosed Research extension has positive support in both the documented extension architecture and the policy's explicit extension allowance. This does not establish that merely detecting another paid application may unlock arbitrary dormant Write features, or that a particular sibling-bundle loader will be accepted. The concrete product, installation path, and commercial arrangement must be reviewable. App Review is an outstanding distribution result, not something a successful local build can prove.

## 6. Domain-owned persistence executables

The existing [Work Session contract](../architecture/work-session-contract.md) gives authority to a Suite helper. The user is now reconsidering that process arrangement: Write would own authoritative Works, and Research would own authoritative Source Libraries, while the persistence-handling module runs in a separate executable. A library or framework implements that domain's persistence capabilities; the executable hosts them independently of the visible application's lifetime. This is the current design direction, with packaging and transport still open; this research does not write a replacement ADR.

| Candidate | Architectural consequence |
|---|---|
| Dedicated Suite helper | Applications present and request changes; a separately supervised process owns authoritative document state. Its installation and lifetime require proof. |
| Domain-owned persistence executable | Write's domain coordinates Work mutations; Research's domain coordinates Source Library mutations. Each persistence module has an executable host. Cross-domain operations request changes from the relevant owner, independently of its visible windows. |

The second arrangement matches the [Source Library contract](../architecture/source-library-contract.md): a Work's Source Record is an independent copy, so Write can own its edits while Research owns the fuller library record. Reconciliation connects the owners without making them concurrent writers of one record. The essential safety requirement is one controlled mutation path per authoritative document state, with recoverable acceptance; it does not by itself require one global Suite process.

A picker extension's process is not automatically the canonical Research authority. Apple documents process reuse when available and connection-related suspension, but does not promise that every host shares one application-wide extension instance. Multiple providers or processes must route library changes to the intended owner rather than silently create independent authoritative stacks. [Adding app-extension support and managing process lifetime](https://developer.apple.com/documentation/extensionfoundation/adding-support-for-app-extensions-to-your-app)

ServiceManagement supplies registration for helpers and launch agents embedded within an application. The inspected `SMAppService.h` in Xcode 26.6 documents that registering a login item starts it immediately and on later logins; launch-agent registration likewise bootstraps it and registers future login behavior. These are deployment choices to assess if either ownership model needs a persistent service; they are not prerequisites for beginning a capability or picker experiment. [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [Registration behavior](https://developer.apple.com/documentation/servicemanagement/smappservice/register())

For user-owned documents outside app containers, Apple documents passing file access between processes using implicitly scoped URL bookmarks. It distinguishes that handoff from explicitly security-scoped bookmarks used for later persistent access, and supports document-relative bookmarks for supporting files. This provides a concrete path for the UI to hand a selected Work package to a helper; grant persistence and recovery through helper restart still need testing. An App Group alone does not confer access to every Work or Source Library the user has stored elsewhere. [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

The remaining lifecycle decisions are precise: whether the owner must be running, what closing its last window or quitting means to dependent operations, where accepted changes remain recoverable, and how another application reaches the owner. These should follow the chosen workflows. Neither a dedicated global helper nor independent per-view persistence follows automatically from sandboxing.

## 7. Distribution comparison

The table summarizes the evidence above. “Candidate” means technically grounded but not yet a tested Folio implementation; Store entries never promise acceptance.

| Arrangement | Direct, nonsandboxed and hardened | Direct, sandboxed | Mac App Store |
|---|---|---|---|
| Frameworks and reusable UI embedded in each application | Documented baseline | Documented baseline | Self-contained baseline |
| Same-team capability services over authenticated IPC | Candidate; choose service ownership | Candidate; App Groups and file grants matter | Candidate; packaging and helper lifetime must meet Store rules |
| Research supplies a custom extension and remote UI to Write | Candidate | Candidate | Explicitly documented extension architecture; enablement and review required |
| One suite runtime installed at `/Library/Frameworks` | Historical supported arrangement; modern signing and lifecycle proof needed | Installation and executable-access boundaries require proof | Shared installation conflicts with the Store packaging boundary |
| Write dynamically loads a framework from Research's bundle | Technically plausible; loader/version/removal proof needed | Additional location, sandbox, and signing proof needed | Exact arrangement unproven; do not use as the baseline |
| Sandboxed front end with nonsandboxed service for broader work | Possible direct architecture | Explicit DTS option, with a real privilege boundary | Do not assume this direct-distribution option is acceptable |
| Framework binaries copied to a shared writable data container at runtime | Requires an explicit trust and update design | Sandbox can allow group-container execution; signing and delivery remain separate constraints | Not an established compliant delivery mechanism |

The group-container row does not assert a universal execution prohibition: Apple's file-access documentation expressly distinguishes executable access in app/group containers from ordinary user-selected file grants. That runtime allowance does not authorize a Store app to install shared code or bypass signing requirements. [Sandbox file and executable access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

## 8. Bounded proof before a distribution decision

**Verification performed:** primary-source review and read-only SDK inspection with Xcode 26.6 (17F113), macOS SDK 26.5, and Folio's macOS 26.5 deployment target. The inspected headers and Swift interfaces confirm API availability and the Objective-C/Swift interface split. No signed two-app runtime experiment, notarization, or App Review submission was performed for this research.

Build a disposable two-app experiment after agreeing its scope; this research has not created or run one. Use the current minimum OS and real signing, with library validation left enabled. Keep it independent of production Work persistence initially.

1. **Baseline and enhancement:** a host edits one Citation without Research. A separate Research-like app supplies a provider that returns a structured Source selection. Confirm installation discovery, required user enablement, and disabling/removal while the host remains open.
2. **Shared UI:** show one picker or inspector. Verify keyboard focus, selection return, menu commands, Undo responsibility, accessibility, drag/drop, resize, cancellation, and provider crash. Determine which interactions can remain native in the host and which need explicit protocol messages.
3. **Access and authority:** pass a user-selected test package and a supporting file to a signed service. Verify actual read/write rights, coordinated access, relaunch recovery, revoked access, and failure without loss. Do not treat a URL string as access authorization.
4. **Independent versions and ownership:** test old host/new provider and the reverse, duplicate installed provider versions, app relocation, service registration, app removal, and update while connected. Launch normally through Finder as well as through Xcode. Verify simultaneous Write and Research operations reach the same relevant document owner, including after owner crash/restart, without double commits. Reject incompatible capability versions while preserving baseline editing and stored data.
5. **Optional literal loading experiment:** only if one physical framework copy still has a concrete benefit, test `Contents/Frameworks`, literal `Contents/SharedFrameworks`, and loading from a companion in and outside `/Applications`. Record sandbox denials, signing and loader results separately. Do not copy code into shared writable storage as a workaround.
6. **Distribution evidence:** exercise the direct signed/notarized configuration and the intended sandboxed configuration separately. Validate an actual Store archive and explain the enhancement and lifecycle to App Review when pursuing that channel. A successful signature check or notarization is not the Store result.

## 9. Consequences for the framework plan

The recommended source structure remains compatible with the user's proposal: FolioKit supplies shared foundations, primary domain frameworks supply deeper capabilities and reusable UI, and internal libraries hide implementation. Public framework boundaries should define both local operations and explicit capability interfaces where another process may own the implementation. Runtime providers should advertise versioned capabilities; installation alone is not a sufficiently strong contract.

The [earlier integration research](macos-suite-language-and-integration-architecture.md) recommended an explicitly reduced App Store profile before these narrower extension questions were resolved. This research refines that recommendation: **modularity, shared UI, and optional cross-application enhancement do not themselves justify reducing the Store product.** Broad automation, machine-wide installation, arbitrary third-party code, and document authority lifetimes still need their own decisions and proofs.

[ADR 0003](../adr/0003-distribute-an-integrated-suite.md) remains the approved direct-distribution posture; this note does not replace it with separate Store products. [ADR 0004](../adr/0004-helper-owned-work-sessions.md) records the existing helper design, now explicitly under reconsideration. The evidence supports exploring a sandbox-compatible implementation of the modular vision before deciding whether the Store requires any material product compromise.
