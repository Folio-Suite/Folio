<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Suite installer

Issue #17 packages one coordinated build for a clean macOS 26.5 or later installation.
This is an unsigned test installer. Public distribution signing and notarization
belong to #19; upgrade, downgrade, and running-app policy belong to #18.

## Layout

| Installed path | Contents |
| --- | --- |
| `/Applications/Folio/Write.app` | Write and its bundled WriteXPCService |
| `/Applications/Folio/Research.app` | Research and its bundled ResearchXPCService |
| `/Applications/Folio/Composer.app` | Composer and its bundled ComposerXPCService |
| `/Library/Frameworks` | FolioKit, WriteKit, ResearchKit, ComposerKit |

The apps link shared Kits without embedding copies. The Suite configuration adds
`/Library/Frameworks` to runtime lookup for apps, Kits, and services. Framework
resources remain in their owning framework bundles. Installed files belong to
`root:wheel`; directories and executable files use 0755, other regular files 0644.
Framework symlinks retain their relative targets. Bundle relocation is disabled.
No installation scripts or background services are added.

## Build and package

Use Xcode 26.6, its command-line tools, and Ruby 2.6 or later with standard libraries
only. The packaging command uses macOS `ditto`, `plutil`, `otool`, and `pkgbuild`.
Commit source changes first, then run from the repository root:

```sh
ruby scripts/release.rb build --candidate /tmp/folio-candidate --configuration Release
ruby scripts/package.rb --candidate /tmp/folio-candidate \
  --products /tmp/folio-candidate/DerivedData/Build/Products/Release \
  --output /tmp/folio-package
```

Use new candidate and output directories. Packaging neither builds nor increments
the Suite counter, and never installs on the development machine. It verifies the
candidate identity against all shipping bundles, rejects missing executables,
embedded framework copies and obsolete dylibs, and stages only the seven shipping
bundles (including their three nested XPC services). Build-directory test products
are not selected. Failed packaging can leave diagnostic staging output; retain or
remove that output before retrying in a new directory.

The stable receipt identifier is `dev.foliosuite.Suite`. Its package version is
`<marketing version>.<build>`, for example `0.1.0.7`; different builds of a release
therefore have distinct package versions. This does not implement an upgrade policy.

The output contains the PKG, staged `payload`, `components.plist`, and `package.json`.
The manifest records the source revision and build-number patch from the candidate,
Suite identity, packaging command, host/tool information, package SHA-256, and
sorted payload paths, permissions, symlink targets, and regular-file SHA-256 values.
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
4. In Write, create a Work, enter distinctive text, save a `.fwdoc`, close it and
   reopen it from Finder. Verify the text. In Research, create and save a
   `.frlibrary`, close it, and reopen it from Finder. Record native type discovery
   and any errors. Preserve these files with the proof results.
5. Inspect the loaded images of all three app processes with `vmmap PID`; record
   that Folio Kits resolve from `/Library/Frameworks`. For each installed XPC
   executable, run `otool -L` and `otool -l` if command-line tools are available.
   Static dependency inspection alone does not prove XPC process loading: record
   an actual service launch and its loaded framework images before marking that
   acceptance criterion passed. The empty service protocols have no domain
   operation, and this ticket does not add one or a shared host.
6. Record results and failures, screenshots where useful, receipt information,
   artifact hash and exact environment. Keep #17 open until installed runtime,
   document round trips, and XPC loading have been demonstrated.

The clean-environment run is pending; the user will provide the environment.
