<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite version and build numbering

Folio has one release identity for Write, Research, Composer, the four Kits, and
all three bundled XPC services. The native About panels use standard bundle
version/build metadata. Mixed Suite versions remain unsupported.

## Scheme-owned numbering

`Config/Version.xcconfig` supplies the shared release version and current build
number. The release version starts at **0.1.0** and is changed deliberately using
`major.minor.patch`. During 0.x, interfaces and document contracts still evolve.

The shared **Folio** scheme advances `CURRENT_PROJECT_VERSION` once in its Build
pre-action. Xcode runs that pre-action for both Build (`ACTION=build`) and Archive
(`ACTION=install`), before compilation reads the number. There is deliberately no
second increment in Archive's own pre-action: that action runs too late for this
purpose in the current toolchain. Clean does not allocate. Build-for-testing and
other operations that actually invoke Folio's Build action also advance the number.
Failed build attempts may consume a number; numbers are not rolled back.

The other schemes have no increment actions. Write, Research, Composer, and
FolioKit builds reuse the latest shared number. No target build phase increments
independently. The new value is used by all targets in the same Suite invocation,
including incremental builds. Do not override `CURRENT_PROJECT_VERSION` on the
command line: that would mask the value allocated by the pre-action.

The Ruby pre-action locks a stable file in the checkout's Git directory, validates
the counter, writes a complete replacement beside the configuration, and atomically
renames it into place. It syncs the file and containing directory before returning.
Readers never see a truncated configuration. Numbers are decimal integers from
1 through 9999; exhaustion and malformed configuration fail the action explicitly.

Building Folio intentionally changes the tracked build-number line. Close Xcode
before editing project or scheme files, validate complete replacements before
installing them, and reopen it for native validation. Never save partial project
or scheme state, even temporarily.

## CI and concurrent work

Run builds of a given checkout serially. The counter update is locked, but the
lock does not span an entire Xcode build. Different configurations still read the
same shared source configuration, so concurrent builds in one checkout could
observe each other's counters.

CI must retain the latest counter across jobs, seed each fresh checkout from that
retained value, and serialize allocation/build jobs for the Suite. A fresh clone
only knows the committed number. This is scheme rigging for future CI, not a
multi-host allocation service. Do not reset the counter or distribute component-only
build products as a coordinated Suite.

## Record a completed build

Integration scripts use Ruby 2.6 or newer and its standard library, Git, and the
active Xcode tools. No gems are required. Build in Xcode or with the normal CLI:

```sh
xcodebuild -workspace Folio.xcworkspace -scheme Folio -configuration Release build
ruby scripts/release.rb prepare --products /absolute/Build/Products/Release --output /absolute/candidates/folio-build
```

`prepare` validates the shipping bundle identities and records the completed build
without advancing the number. It writes `release.json` with the version, build,
Git revision, dirty state, and the exact build-number patch relative to that
revision. The automatic counter edit is allowed; other source changes must be
committed first. Keep each candidate directory intact and choose a new output
location for subsequent builds.

For a combined signed Xcode build and recording operation:

```sh
ruby scripts/release.rb build --candidate /absolute/candidates/new-folio-build
```

This defaults to Release. It invokes Folio without overriding the allocated build
number, verifies exactly one increment, validates the bundles, and records the
identity and build report. Use `--configuration Debug --action build-for-testing`
for native test products. Outputs must be outside source or Git-ignored. A failed
build leaves its diagnostic output but no completed candidate record; choose a
new directory for a subsequent attempt.

Every new Folio build gets a new number, including rebuilding the same revision.
The earlier independent ledger allocator and pinned-number rebuild workflow are
superseded by this scheme rule. Existing candidate metadata remains usable for
verification; creating or inspecting metadata never allocates a number.

## Validation

```sh
ruby scripts/tests/release_test.rb
ruby scripts/release.rb verify --products /absolute/Build/Products/Debug
ruby scripts/release.rb verify --products /absolute/Build/Products/Release --candidate /absolute/candidates/folio-build
```

Verification requires all three apps, all four Kits, and the three embedded
services, including Folio framework copies inside shipping bundles. It checks the
current shared configuration, or recorded candidate identity when provided.
Xcode test-runner products are excluded. Missing products, unexpected identities,
and mismatched version/build metadata fail validation.

The clean Suite build check includes identity validation and now advances the
counter because it builds Folio. Native About tests cover displayed metadata.
Installer payload assembly, distribution signing, notarization, and automatic
updates remain subsequent work; a successful archive does not establish those.
