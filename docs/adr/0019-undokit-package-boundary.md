<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Track UndoKit as an independently versioned submodule

Accepted by the maintainer on 2026-10-08 as the source and distribution
refinement to [ADR 0015](0015-swift-suite-and-independent-frameworks.md). The
Folio repository tracks [Folio-Suite/UndoKit](https://github.com/Folio-Suite/UndoKit)
as a Git submodule at `UndoKit/`. The submodule keeps the existing source and
native Xcode project available in Folio's workspace while preserving UndoKit as
an independently versioned project and repository. Folio is its primary
consumer; the same source repository also provides the Swift Package product
for other consumers, including KitchenMemory.

UndoKit retains its native Xcode project and standalone framework target; its
project defaults to version **0.1.0** and does not inherit the Folio Suite
version. The existing Swift Package product remains available to other
consumers. The Xcode project and package currently target macOS 14; iOS support
requires separate qualification. Objective-C interfaces and XCFramework
distribution remain deferred.

Folio builds the UndoKit framework through the submodule's native Xcode project
within the established six-framework Suite and standalone-app topology. The
Suite owns five Kit identities; UndoKit owns the sixth independently. Folio apps
retain their established installed Suite and standalone runtime layouts,
including framework resources. UndoKit owns its implementation and resources;
Folio hosts own semantic integration and policy.

The submodule gitlink records one exact UndoKit commit. Recursive clone and
submodule initialization reproduce that selected source revision; submodules do
not float to newer commits when a tag moves or a newer tag appears. Update the
gitlink deliberately after selecting a tag allowed by the lifecycle policy in
[Suite version and build identity](../release-numbering.md), then commit the
parent repository change. The gitlink, rather than a broad dependency range,
is the source-revision record for Folio builds.

UndoKit supports macOS 14 today. iOS support remains unqualified and must be
established separately through the existing [KitchenMemory issue #236](https://github.com/ctwelve/KitchenMemory/issues/236).
This issue is the future platform-qualification route; the extraction does not
claim iOS compatibility.

Issue ownership follows behavior. Generic framework bugs and capability work
belong in the UndoKit repository. Folio host integration, Work semantics,
compensation, receipts, policy, and Suite behavior remain in Folio's tracker.
Cross-repository changes should link their related issues.

This decision supersedes ADR 0015's monorepo development-ownership model and its
deferral of external Swift framework and package availability until after Folio
1.0. The original `ctwelve/UndoKit` repository was deleted as recorded in its
historical provenance; this decision uses the new Folio-Suite repository and
does not restore that deleted remote. Objective-C interfaces and XCFramework
distribution remain deferred. ADR 0015 remains the record of the earlier Swift
and framework-independence decision; its Folio-first generic boundary and
host-owned semantics remain in force. Existing Folio integration contracts
continue to define the host boundary. Historical source and design evidence
remain in the submodule's [provenance record](../../UndoKit/UPSTREAM.md).
