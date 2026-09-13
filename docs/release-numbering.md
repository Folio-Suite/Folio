<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite version and build numbering

Folio has one release identity for Write, Research, Composer, the four Kits, and
all three bundled XPC services. The native About panels report the applications'
standard bundle version and build metadata. Mixed Suite versions remain unsupported.

## Development identity

`Config/Version.xcconfig` is the authoritative development configuration, included
by the shared Suite configuration. The initial identity is **0.1.0 (1)**: an early
development release, replacing the independent Xcode template values. All project
configurations and targets inherit it, including test bundles. Keep both values
literal; avoid target overrides or build phases that edit the configuration.

Choose `major.minor.patch` deliberately: advance patch for fixes, minor for new
capabilities, and major for a deliberate compatibility milestone. During 0.x,
interfaces and document contracts continue to evolve; the number does not promise
independent Kit compatibility. Version changes are reviewed source changes.

Build numbers are increasing decimal integers, currently limited to 1–9999 by
this workflow. Build 1 is reserved for ordinary development. Preparing a new
candidate allocates the next number across all release versions; rebuilding that
candidate retains its number. Ordinary Xcode builds neither allocate numbers nor
change source files. Allocation exhaustion fails explicitly rather than wrapping.

## Establish one allocation authority

The integration command requires Ruby 2.6 or newer with its standard library, Git,
and the active Xcode command-line tools. No gems are required. The system Ruby on
the current development Mac works; an explicitly installed Ruby can also run it.

Choose one durable ledger on the designated release-preparation Mac, outside the
checkout. Every checkout preparing distributable Folio builds must use that same
ledger. Initialize it once with the highest build number already reserved or
distributed (1 for this initial setup):

```sh
ruby scripts/release.rb init-ledger --ledger /absolute/release-state/folio-builds.json --last-build 1
```

The command refuses to overwrite an existing ledger. Preparation locks a stable
companion lock file, then atomically replaces the ledger after flushing its new
reservation. Concurrent preparations sharing this authority get different numbers.
A failure after reservation may leave a gap; reserved numbers are never recycled.

Back up and transfer the ledger together with release records. Do not initialize
independent ledgers on several machines, restore an old counter, delete its lock
file during use, or place it in a cloud-synchronized folder. Local file locking is
not a distributed allocation service. For CI or another release host, designate a
single authority or transfer the complete latest state while preparation is stopped.
After losing state, recover the highest reservation from all retained release
records before explicitly establishing a replacement authority. The tool cannot
detect reservations held only by an unrelated or lost ledger.

## Prepare and rebuild a candidate

Commit source changes first. Preparation records the Git revision, release version,
allocated build, ledger identity, UTC preparation time, and `dirty: false` in
`release.json`. Tracked changes and untracked source files cause preparation to
fail. This keeps the recorded revision sufficient to recover the source inputs;
dirty candidates are intentionally unsupported.

```sh
ruby scripts/release.rb prepare --ledger /absolute/release-state/folio-builds.json --output /absolute/candidates/folio-candidate
ruby scripts/release.rb build --candidate /absolute/candidates/folio-candidate
```

`build` defaults to Release and uses the enclosing Folio workspace. It applies both
recorded values to every Xcode target, checks the checkout against the candidate,
then validates the actual shipping bundle metadata. Derived data stays inside the
candidate directory. A successful build writes `build-Release.json` with the
identity, Xcode version, configuration, invocation, products location, and validation
time. An attempted rebuild invalidates the previous success report before invoking
Xcode; a failed build does not create a fresh success report.

Run the same `prepare` command against the same candidate to reuse its identity.
It checks the revision, version, and ledger association rather than allocating again.
Run `build` again to rebuild without touching the ledger. To prepare another build,
choose a new candidate directory. Never edit a candidate manifest by hand.

For a signed native test build, use:

```sh
ruby scripts/release.rb build --candidate /absolute/candidates/folio-candidate --configuration Debug --action build-for-testing
```

Then use Xcode's signed test runner with the candidate's derived-data directory.
Outputs and allocation state must be outside source or in Git-ignored locations;
they must not become source changes themselves. Existing unrelated output
directories are not overwritten. Developer signing/team configuration remains the
existing Xcode setup; this command does not produce distribution signatures, a PKG,
or a notarized artifact. Those are subsequent tickets.

## Validation

```sh
ruby scripts/tests/release_test.rb
ruby scripts/release.rb verify --products /absolute/Build/Products/Debug
ruby scripts/release.rb verify --products /absolute/Build/Products/Release --candidate /absolute/candidates/folio-candidate
```

Without a candidate, verification expects the shared development configuration.
With a candidate, it expects that recorded identity. It requires all three apps,
all four Kits, and the three embedded services, and checks Folio bundles nested in
the shipping products as well. Xcode test-runner products are outside this payload.
A missing bundle, unexpected shipping identity, or version/build mismatch fails.
This checks metadata, not binary provenance, signing, or installation behavior;
use the candidate build command to connect the recorded source to the build.

The normal clean-build check includes development identity validation. Native UI
tests exercise each application's About panel using the same inherited identity.
Preparation tests exercise reuse, concurrent allocation, dirty-source rejection,
ledger safeguards, and positive and negative bundle validation through the CLI.
