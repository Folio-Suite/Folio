<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite installer

Issue #17 packages one coordinated build for a clean macOS 14 Sonoma or later installation.
This is an unsigned test installer. Public distribution signing and notarization
are future distribution work. Tickets #18 (upgrades) and #19 (signed distribution)
were closed as not planned at this pre-alpha stage on 2026-09-26. Retain their
historical checklists as reference when distribution is deliberately resumed.

## Layout

| Installed path | Contents |
| --- | --- |
| `/Applications/Folio/Write.app` | Write and its bundled WriteXPCService |
| `/Applications/Folio/Research.app` | Research and its bundled ResearchXPCService |
| `/Applications/Folio/Composer.app` | Composer and its bundled ComposerXPCService |
| `/Library/Frameworks` | FolioKit, WriteKit, ResearchKit, ComposerKit, UndoKit, TypographyKit |

The apps link shared Kits from `/Library/Frameworks` without embedding Folio Kit
copies. Swift package dependencies are embedded in each app's
`Contents/Frameworks`: only generated `Algorithms_*_PackageProduct.framework`,
`Collections_*_PackageProduct.framework`, `Defaults_*_PackageProduct.framework`,
and `RealModule_*_PackageProduct.framework` products, plus
`libswiftCompatibilitySpan.dylib`, are accepted there. Packaging copies their
signed contents and records their files in the payload manifest; it does not
re-sign them. Suite Kit frameworks, unapproved frameworks or dylibs, test bundles,
and debug-symbol bundles remain rejected inside app bundles. Framework resources
remain in their owning framework bundles. Installed files belong to
`root:wheel`; directories and executable files use 0755, other regular files 0644.
Framework symlinks retain their relative targets. Bundle relocation is disabled.
No installation scripts or background services are added.

## Build and package

Use Xcode 27, its command-line tools, and Ruby 2.6 or later with standard libraries
only. The packaging command uses macOS `ditto`, `plutil`, `otool`, and `pkgbuild`.
Commit source changes first, then run from the repository root:

```sh
ruby scripts/release.rb build --candidate /tmp/folio-candidate --configuration Release
ruby scripts/package.rb --candidate /tmp/folio-candidate \
  --products /tmp/folio-candidate/DerivedData/Build/Products/Release \
  --output /tmp/folio-package
```

Use new candidate and output directories. Packaging neither builds nor changes
the Suite identity, and never installs on the development machine. It verifies the
candidate identity against all shipping bundles, rejects missing executables,
unexpected embedded frameworks or dylibs, missing required storyboards/models/assets,
and debug products, and stages the nine shipping bundles plus their three nested
XPC services. Build-directory test products
are not selected. Failed packaging can leave diagnostic staging output; retain or
remove that output before retrying in a new directory.

The stable receipt identifier is `dev.foliosuite.Suite`. Its package version is
`<marketing version>.<build>`, for example `0.1.0.7`; different builds of a release
therefore have distinct package versions. This does not implement an upgrade policy.

The output contains the PKG, staged `payload`, `components.plist`, and `package.json`.
The manifest records the candidate's source revision and Suite identity, packaging
command, host/tool information, package SHA-256, and
sorted payload paths, permissions, symlink targets, and regular-file SHA-256 values.
Current candidates require clean committed source and do not contain a build-number
patch; historical candidates retain their original identity metadata, including a
patch when one was recorded. See [Suite identity](release-numbering.md).
Keep this manifest alongside the PKG. Reproducibility means repeatable inputs and
payload composition, not identical compressed or signed package bytes.

## Clean-install proof

Run these checks on a disposable clean Mac or VM, without Xcode, a Folio checkout,
previous Folio frameworks, or DYLD environment overrides. Transfer the PKG and its
manifest. Record the macOS version/build, architecture, package SHA-256 and Suite
identity. Do not substitute a successful developer build for this proof.

1. Verify the PKG hash against `package.json`. Install with Installer, or
   `sudo installer -pkg /path/to/Folio-VERSION.BUILD.pkg -target /`.
2. Record `pkgutil --pkg-info dev.foliosuite.Suite` and inspect the installed paths,
   permissions and the three nested XPC services. Verify each installed regular
   file against the manifest inventory and each symlink target.
3. Launch each app from `/Applications/Folio`. Confirm its native About version,
   menus and localized UI. Write's editor must load its framework storyboard and
   formatting resources. Composer is only expected to display its current shell.
4. In Write, create a Work, enter distinctive text, save a `.flwrbundle`, close it and
   reopen it from Finder. Verify the text. In Research, create and save a
   `.flrsbundle`, close it, and reopen it from Finder. Record native type discovery
   and any errors. Check the native and ZIP type badges separately; ZIP opening
   and Composer document saving are not implemented for the newly declared types.
   Preserve these files with the proof results.
5. Inspect the loaded images of all three app processes with `vmmap PID`; record
   that Folio Kits resolve from `/Library/Frameworks`. For each installed XPC
   executable, run `otool -L` and `otool -l` if command-line tools are available.
   Static dependency inspection alone does not prove XPC process loading: record
   an actual service launch and its loaded framework images before marking that
   final-artifact acceptance criterion passed. The service protocols expose a diagnostic ping but no domain
   operation, and this ticket does not add one or a shared host.
6. Record results and failures, screenshots where useful, receipt information,
   artifact hash and exact environment. Repeat these checks for the exact final
   distribution artifact when distribution work resumes; development evidence is scoped below.

The historical evidence below uses the then-current `.fwdoc`, `.frlibrary`, and
`.fcedition` registrations. It does not validate the replacement extensions,
new document badges, or reserved ZIP/Composer formats. Repeat the relevant
Finder checks against the final candidate; see [file types](document-file-types.md).

The pre-alpha development installer milestone (#17) is accepted with the Sonoma
installation and separately identified XPC diagnostic evidence below. On
2026-09-26, its scope was reconciled to development infrastructure, not release
qualification: the shared checkout was visible, and the service probe used a
separate diagnostic build. Those limitations remain explicit. Exact final-artifact
verification without a checkout and upgrade behavior remain future distribution
requirements. Their former tickets #18/#19 are closed as premature, not verified.
The preparation evidence below belongs to its recorded older revision and toolchain.
Use a newly prepared candidate for final distribution acceptance; do not treat
the historical payload, test count, or signatures as current runtime evidence.

## Sonoma 14.0 smoke test — 2026-09-26

Installed `Folio-0.1.0.1.pkg` from clean source revision
`8ce938d710432d7cd0ac3591a43aa611d3ce0aad`, built with Xcode 27.0 (27A266a),
in the UTM VM `macOS 14.0 Sonoma`: macOS 14.0 (23A344), arm64, 4 GB RAM.
The package SHA-256 is
`45b0e668f0c8746ecfcb1fb0ad0c00ca0de103cf6dd36f7bc7e3b779d08b934d`.
Local artifacts and evidence are in ignored `dist/sonoma-8ce938d/`.

- The guest receipt identifies `dev.foliosuite.Suite`, version `0.1.0.1`.
- Verification checked 355 manifest entries. All file hashes and symlink targets
  matched. Folio-owned paths matched recorded permissions and ownership. The
  existing system `/Applications` directory retained `root:admin` and 0775,
  rather than the staging inventory's `root:wheel` and 0755; it was not altered.
- All three installed apps passed deep, strict signature verification; all four
  shared Kits passed strict verification.
- Write's About panel displayed 0.1.0 (1), and its editor, Manuscript sidebar,
  formatting toolbar, and entered text were observed in the guest.
- Fresh process IDs were recorded after the user reopened all three apps: Write
  1028, Research 1021, and Composer 1024. Each live process mapped FolioKit and
  its own domain Kit from `/Library/Frameworks`.
  The SSH shell had no DYLD environment overrides. The host's Developer folder
  was shared for artifact transfer, so the checkout was visible in the guest;
  the observed Kit mappings were the installed copies, not build products.
- The user reported successful Write save/close/Finder-reopen and Research and
  Composer launch checks. SSH independently confirmed the saved
  `~/Documents/Test Document.fwdoc` and a new Write process after reopening.
  An evidence copy of the saved Work's SQLite store passed `integrity_check`.
- Launch Services registered `.fwdoc`, `.frlibrary`, and `.fcedition` with the
  corresponding Folio document types.

- In a subsequent manual check, the user saved documents in all three apps,
  closed all three, and successfully relaunched each by double-clicking its
  document in Finder. SSH confirmed `Write.fwdoc/Work.sqlite`,
  `Research.frlibrary/Library.sqlite`, and Composer's current SQLite document
  `Composer.fcedition` in the guest's Documents folder. Fresh processes were
  Composer 1063, Write 1071, and Research 1074. Evidence copies of all three
  databases passed `integrity_check`. This verifies the current shells' document
  round trips, not future Edition package persistence or Research catalog features.

Actual XPC service launches were subsequently checked with the diagnostic build
below, not the original installer’s empty-protocol service binaries.
The combined evidence supports the scoped pre-alpha milestone; it does not
establish Intel, upgrade, notarization, or full localization coverage.

## Development-only XPC probe

`scripts/build-xpc-probe.rb` builds a standalone diagnostic app containing copies
of the three services from a signed Suite build. It preserves the service
signatures, signs the harness with the supplied identity, and records file hashes
and source provenance in `probe.json`. It does not modify or install shipping
apps. Build with the same team used for the services and installed frameworks:

```sh
ruby scripts/build-xpc-probe.rb --products /path/to/Build/Products/Release \
  --output /tmp/folio-xpc-probe --identity "$FOLIO_SIGNING_IDENTITY"
```

Copy the complete `FolioXPCProbe.app` to the test Mac, which must already have the
matching Suite frameworks installed. Run its executable from a terminal or SSH:

```sh
/path/to/FolioXPCProbe.app/Contents/MacOS/FolioXPCProbe 120
```

The harness sends a unique nonce over `NSXPCConnection` to each embedded service.
Each service echoes it and returns its own process ID. The harness requires three
matching replies within 15 seconds, prints JSON records, and holds connections
for the requested 0–300 seconds (default 60) for `vmmap PID` inspection. Failure,
interruption, invalid replies, or timeout produce a nonzero exit. Inspect the
returned PIDs rather than reusing PIDs from earlier runs. This diagnostic has no
domain operation and proves neither Work Session authority nor persistence over XPC.

On 2026-09-26, the diagnostic services were rebuilt with Xcode 27 from base
`8ce938d` plus the local ping changes; the shipping Kits were unchanged. A signed
probe ran in Sonoma 14.0 (23A344) from `~/FolioDiagnostics/FolioXPCProbe.app`:

- All three nonce exchanges passed: Write PID 1197, Research PID 1198, Composer
  PID 1199. All were separate processes parented by launchd (PID 1).
- Live `vmmap` records confirmed each service loaded FolioKit and its domain Kit
  from `/Library/Frameworks`, without embedding framework copies in the probe.
- Probe signature verification passed in the guest. Raw exchange records,
  process paths, mappings, and the probe manifest are in ignored
  `dist/xpc-probe-sonoma/`.
- A separately signed negative-control app without embedded services reported
  three connection errors, zero replies, and exited with status 1.

These results prove native XPC startup, request/reply, and installed dependency
loading for the diagnostic service binaries. They do not retroactively prove
the original PKG's service binaries, or connections from shipping application
clients, which are not implemented. A future release candidate must retain its
own artifact identity and acceptance evidence.

## Preparation evidence — 2026-09-13

Prepared `Folio-0.1.0.9.pkg` from source `49e045b` plus the recorded build-counter
patch (8 → 9). Artifact and manifest are in ignored `dist/issue-17-build-9/`.
The package SHA-256 is:

```text
7c92beda72e6dc40e3c7937b6d20416611ac72766837ce7e651d2eca569099b6
```

On macOS 26.6.2 (25G83), Apple Silicon, Xcode 26.6:

- Release build and coordinated bundle-identity verification passed.
- `pkgutil --expand-full` reproduced all 198 manifest entries with matching file
  hashes and symlink targets, and no extra paths.
- Extracted app bundles passed `codesign --verify --deep --strict`; all four
  extracted Kits passed strict signature verification. These are existing build
  signatures; the installer itself is unsigned and unnotarized.
- All 41 native tests passed (46 executions), using signed Debug test products.
- Packaging tests passed, including extracted layout, receipt/version, excluded
  test products, and rejection of missing candidates, executables, and models.
  Existing release-numbering and localization tests also passed.
- Standards and Spec review findings were addressed: share the shipping inventory
  between commands, and reject missing required runtime resources.

No installation occurred on the development Mac in that historical run. Installed
resource loading, Finder document round trips, and XPC process loading were not
verified by that run; see the separately scoped September 26 evidence above.
