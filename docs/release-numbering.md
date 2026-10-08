<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite version and build identity

`Config/Version.xcconfig` supplies **0.1.0 (1)** to Write, Research, Composer,
the five Folio-owned frameworks, and all three bundled XPC services. The native
About panels use this standard bundle metadata. Mixed Suite versions remain
unsupported. UndoKit is the sixth framework with its own identity; its Xcode
project defaults to **0.1.0** and does not inherit the Suite version.

Builds, tests, and archives do not allocate numbers or modify tracked source.
The former scheme pre-action and counter script have been removed. Change the
shared configuration deliberately when needed. A release-service numbering
policy remains future work; development CI does not distribute release products.
Its diagnostics are identified by Git revision, GitHub run ID, and attempt.

This is the current scope of [issue #16](https://github.com/Folio-Suite/Folio/issues/16).
Commit `b8c3fe1` supersedes its original automatic allocation/ledger requirement
and the intervening Folio scheme counter. Candidate recording verifies an existing
identity; it is not a uniqueness service or permission to distribute reused build
numbers. Unique identities for distributed releases remain unresolved release
engineering work and must be settled before public distribution. Future upgrade proofs must retain distinct, deliberately prepared old/new
identities. Neither a development test package nor a local signed artifact
establishes a release-numbering policy. Tickets #18 and #19 were closed as not
planned at this pre-alpha stage; revisit their historical requirements when
distribution work resumes. Retain historical candidate identities unchanged.

## UndoKit tag stages

UndoKit's version follows its own lifecycle, independent of the Folio Suite
version. At the development stage, Folio may pin an UndoKit tag within the
approved **major-version range**; while UndoKit is 0.x this includes minor
versions below 1.0.0 and may include source or API changes. At beta, select tags
within the approved **minor-version range**. During release engineering, select and record an **exact tag**. These rules constrain which
tag Folio may choose at each stage; they do not make the submodule float.

The submodule gitlink commits one exact UndoKit commit. To change it, select a
stage-allowed tag, check out that tag in `UndoKit/`, and commit the updated
gitlink in Folio. A clone or update reproduces the committed gitlink even when
new tags later appear. See [CONTRIBUTING.md](../CONTRIBUTING.md) for recursive
checkout instructions.

Close Xcode before editing project or scheme files, validate complete replacements,
and reopen for native validation. Never save partial project or scheme state.

## Record and verify a completed build

The Ruby release tooling retains bundle validation and candidate recording without
allocating a number. Candidate recording requires committed, clean source,
including the version configuration. Existing historical candidate records remain
readable for verification. The tooling uses Ruby 2.6 or newer and its standard
library, Git, and the active Xcode tools; no gems are required.

```sh
xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Release build
ruby scripts/release.rb prepare --products /absolute/Build/Products/Release --output /absolute/candidates/folio-build
ruby scripts/release.rb verify --products /absolute/Build/Products/Release --candidate /absolute/candidates/folio-build
```

`prepare` records the version, build, Git revision, `dirty: false`, the shared
configuration numbering mode, and preparation time in `release.json`. It rejects
uncommitted source instead of recording a new build-number patch. Keep candidate
directories intact and use a new output location
for each attempt. To build and record together:

```sh
ruby scripts/release.rb build --candidate /absolute/candidates/new-folio-build
```

This defaults to Release and verifies that source identity did not change during
the build. `--configuration Debug --action build-for-testing` prepares native test
products. Output must be outside source or Git-ignored. Failed builds retain their
diagnostic output without a completed candidate record.

Candidate verification checks all three apps, six frameworks, three embedded
services, and nested framework copies. Folio-owned products use the Suite
identity; UndoKit uses its independently recorded version and build. Missing
bundles, unexpected identifiers, and mismatched versions fail validation.

New candidates use schema 2 and include the committed UndoKit revision and its
matching release tag when present. Recording a candidate requires an initialized,
clean submodule at the committed gitlink, even when local Git settings hide
submodule changes. Verification of a saved candidate uses its recorded identities
rather than the current checkout. Historical schema-1 candidates remain readable
without modification; their recorded Suite identity applies to UndoKit as it did
before extraction.

Test runners are excluded. See [Development CI](development-ci.md) for development
checks and [Suite installer](installer.md) for packaging and clean-install proof.
