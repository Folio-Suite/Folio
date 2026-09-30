<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Incremental Work persistence evidence

Issue #52 implementation: `2ae6762c5b5795ba99b630a45e0c33a72b7dd38c`, reviewed against
`79c6beb`. This slice prepares closed native packages and keeps AppKit responsible
for safe replacement. It does not implement the durable-history integration in #53.

## Tests

The public WriteKit and native NSDocument seams were exercised test-first:

- A one-paragraph staging test initially failed because the API was absent.
- The native safe-save test initially failed because snapshot saving changed the
  SQLite store identity. It now preserves that identity across an edit.
- Explicit resource upgrade initially failed because the APIs were absent.
- Boundary tests cover unchanged saves, reorder/deletion, resource corruption,
  failure after cloning with retry, unknown package members, symlink/nested
  staging destinations, and resource FileWrapper round trips.
- Native tests cover Save, Save As, Save To, Auto Save, edited-state preservation
  after failure, retry, reopening, and independent resource copies.

The full Core scheme passed 49 tests on 2026-09-29 through Xcode's signed test
workflow. It includes the existing old-writer fixture compatibility test. The full
Write scheme passed all 15 tests, including its native application and UI tests.
`bash scripts/check-build.sh --analyze` passed the clean Suite analyzer/build,
TypographyKit behavior, public Kit interfaces, release metadata, and all three
unsigned standalone application closure checks. Localization extraction and Ruby
syntax checks also passed. Unsigned build checks do not establish installed runtime
behavior or distribution signing.

## Bounded interruption and work measurement

Run after building the Core scheme:

```sh
ruby scripts/verify-work-persistence.rb "$PWD/DerivedData/Folio/Build/Products/Debug"
```

The runner limits each child to 60 seconds and its sampled process-group RSS to
1 GiB. It creates 5,000 paragraphs and a 32 MiB opaque resource. It kills a writer
once a staged store exists, checks original package hashes and public reopening,
then retries into a fresh private staging directory. It removes its temporary
packages and preserves logs and a report under `build/`.

[The retained report](probe-2026-09-29.json) records the source/framework hashes,
source package hashes before and after interruption, and measured results:

- Interrupted staging exited on signal 9; original bytes were unchanged.
- Retry changed one paragraph and one run; no Content Unit values changed.
- 819,200 store bytes and 33,554,432 resource bytes were cloned; copied bytes: zero.
- Staging took 0.919 seconds; the complete retry process took 1.298 seconds.
- Sampled retry process-group peak RSS was 159,632 KiB.

These are one-run observations on the development Mac, not performance promises.
They supersede the earlier 0.64-second observation made before URL validation was
changed. Clone counts describe logical file sizes, not measured physical I/O.
Validation still traverses text and reads resource bytes; staging is not constant
time. The runner cannot prove power-loss durability or interruption during
AppKit's final replacement. Native Versions restoration and a resource-import UI remain outside this proof.
The copy fallback was subsequently exercised as described below.

## Compatibility

The authored Core Data WorkV1 schema is unchanged. Existing text packages stay V1.
A host explicitly opts into package V2 before importing opaque resources; ordinary
text opening does not upgrade a file. Resource-capable UI must offer upgrade,
continued compatible editing, and cancellation. No such UI is added by this slice.

## Review disposition

The two-axis review compared `79c6beb...2ae6762`.

- Standards: no documented violation; one low-priority duplication observation
  about Core Data open/context/close setup. Read-only validation, staged mutation,
  and temporary snapshot creation keep their explicit lifetimes in this slice.
- Spec: resource-only native edited-state tracking was repaired in `20442e7`.
  Three focused native tests passed after the change: resource-only import/remove
  with Auto Save and reopening, failed mutations/save with retained dirty state
  and retry, and the existing independent resource-copy test. The full suites
  above ran before this follow-up; they were not repeated.
- Spec: the maintainer accepted cloning as the fast path and independent copying
  as the portable fallback. The HFS+ run below completes fallback verification;
  zero unchanged-asset copies is not promised on filesystems without cloning.

## Verified portable fallback

The maintainer accepted the portability boundary before PR delivery: avoid copying
unchanged assets where filesystem cloning is available, and preserve independent
packages through ordinary copying elsewhere. Small text edits still reconcile
only changed authored rows on either path.

The existing public-API probe ran with `TMPDIR` pointing at a disposable, mounted
512 MiB HFS+ sparse image. No injected clone result or production test switch was
used. [The fallback report](fallback-hfs-2026-09-29.json) records:

- Zero cloned bytes; 811,008 store bytes and 33,554,432 resource bytes copied.
- One changed paragraph and one changed run.
- Signal-9 interruption with identical original package hashes before and after.
- Successful retry and public reopening; 0.744 seconds staging, 1.041 seconds
  complete retry, and 160,480 KiB sampled process-group peak RSS.

These numbers are observations from a local disk image, not a comparison of real
APFS and HFS+ device performance. The temporary volume was detached after testing.
To repeat, mount a disposable HFS+ volume with at least 512 MiB available and run:

```sh
TMPDIR=/path/to/disposable-hfs-volume/ ruby scripts/verify-work-persistence.rb \
  "$PWD/DerivedData/Folio/Build/Products/Debug"
```

The runner owns and removes only its temporary fixture directory. Detach the test
volume afterward. All executable sources are unchanged from the preceding tested
implementation; this completion adds evidence and the accepted scope clarification.
