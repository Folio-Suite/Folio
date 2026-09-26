<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite version and build identity

`Config/Version.xcconfig` supplies **0.1.0 (1)** to Write, Research, Composer,
the four Kits, and all three bundled XPC services. The native About panels use
this standard bundle metadata. Mixed Suite versions remain unsupported.

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
engineering work and must be settled before public distribution. Upgrade proofs
under #18 must retain distinct, deliberately prepared old/new identities; neither
#17's test package nor #19's local signed artifact establishes a release-numbering
policy. Retain historical candidate identities unchanged.

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

Verification checks all three apps, four Kits, three embedded services, and nested
Folio framework copies against the shared configuration or a supplied candidate.
Missing bundles, unexpected identifiers, and mismatched versions fail validation.
Test runners are excluded. See [Development CI](development-ci.md) for development
checks and [Suite installer](installer.md) for packaging and clean-install proof.
