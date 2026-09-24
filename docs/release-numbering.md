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

Close Xcode before editing project or scheme files, validate complete replacements,
and reopen for native validation. Never save partial project or scheme state.

## Record and verify a completed build

The Ruby release tooling retains bundle validation and candidate recording without
allocating a number. Candidate recording requires committed, clean source,
including the version configuration. Existing historical candidate records remain
readable for verification.

```sh
xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Release build
ruby scripts/release.rb prepare --products /absolute/Build/Products/Release --output /absolute/candidates/folio-build
ruby scripts/release.rb verify --products /absolute/Build/Products/Release --candidate /absolute/candidates/folio-build
```

`prepare` records the version, build, Git revision, and preparation time in
`release.json`. Keep candidate directories intact and use a new output location
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
