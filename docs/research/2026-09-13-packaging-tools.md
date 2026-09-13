<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Packaging and disk-image tools for Folio

Research date: 2026-09-13. Status: quick survey for discussion; no tool installed or exercised. Capabilities below come from upstream documentation. Compatibility with Folio's exact build and CI environment remains to be tested.

Folio distributes a coordinated Suite through an installer, as recorded in [ADR 0003](../adr/0003-distribute-an-integrated-suite.md). The DMG should carry that PKG and supporting information. A drag-to-Applications layout for separate apps would misrepresent the shared-framework installation model.

## Visual package and disk-image authoring

| Tool | What it adds | Folio assessment |
|---|---|---|
| [Package Builder](https://www.araelium.com/packagebuilder) | Version 2; $30; macOS 13+. Visual destinations, localized introduction/readme/summary and licenses, scripts, requirements, signing/notarization, and a `pkgbuilder` CLI. | Strong visual PKG candidate. Its documented integration with DMG Canvas provides a coherent authoring pair while retaining command-line builds. |
| [DMG Canvas](https://www.araelium.com/dmgcanvas) | Version 4; $30; macOS 11+. WYSIWYG design, Retina and light/dark previews, `dmgcanvas` CLI, signing and notarization. | Strongest visual DMG candidate for the user's preference for visual tools. A PKG carrier is a natural fit; $60 for the two advertised tools before any applicable taxes or discounts. |
| [DropDMG](https://c-command.com/dropdmg/) | Version 3.7.1, released 2025-11-11. Visual layouts, reusable configurations, CLI/AppleScript automation, and signing. [Store](https://c-command.com/store/) lists $24.99 as a one-time purchase. | Credible independent DMG alternative. Its [human-readable shared layout/configuration formats](https://c-command.com/dropdmg/help/sharing-licenses-and-la) suit version control. Its [CLI controls the app and requires a logged-in GUI user session](https://c-command.com/dropdmg/help/command-line-tool), a material CI constraint. |
| [Packages](https://github.com/packagesdev/packages) | Open-source visual installer authoring, with `packagesbuild` for command-line builds. [Commit history](https://github.com/packagesdev/packages/commits/master/) includes February 2026 Tahoe-specific fixes. | Worth a trial as a visual PKG editor. The upstream download website returned 502 during this survey, so current downloadable version and macOS 26 compatibility of that binary were not verified. |
| [Jamf Composer](https://www.jamf.com/products/jamf-composer/) | Enterprise packaging/repackaging workflows. | Lower priority: Folio already builds its own controlled payload, so enterprise repackaging is not the problem we need to solve. This is the Jamf product, unrelated to our Composer app. |

Prices and advertised versions are snapshots from the linked vendors, not purchase quotes. **Visual shortlist:** evaluate Package Builder plus DMG Canvas together, with DropDMG as the alternative DMG designer. These are desk-survey recommendations, not evidence of successful Folio builds.

## Other useful packaging tools

[munki-pkg](https://github.com/munki/munki-pkg) was archived on 2026-09-01; its README points to [swiftpkg](https://github.com/codecarton/swiftpkg). The latter's current README describes version 0.4.1, command-line and native Swiftpkgr interfaces, portable JSON/plist/YAML projects, and signing/notarization through Apple's tools. It is an emerging option to evaluate, rather than a reason to replace working Ruby orchestration immediately.

[Suspicious Package](https://mothersruin.com/software/SuspiciousPackage/) is an inspection companion: it examines package files, scripts, receipts, signatures, and notarization without installation. It would make a useful human review step regardless of which authoring tool we choose.

## Command-line DMG tools

| Tool | Strengths | Tradeoffs and Folio fit |
|---|---|---|
| [create-dmg/create-dmg](https://github.com/create-dmg/create-dmg) | MIT shell tool; packages a source folder, positions icons, sets backgrounds/window geometry, and offers signing plus notarization/stapling options. No extra language runtime required beyond standard macOS. | Best fit with our Ruby/shell preference. Its cosmetic layout uses Finder AppleScript; documented CI/sandbox modes skip that prettification. Put the PKG in its source folder and omit the Applications drop-link option. |
| [dmgbuild](https://github.com/dmgbuild/dmgbuild) | MIT Python tool which explicitly avoids Finder when generating layout metadata. [Settings](https://dmgbuild.readthedocs.io/en/latest/settings.html) configure copied files, icon coordinates, backgrounds, and window presentation. | Strongest CLI candidate for headless layout generation, by design rather than measured comparison. Adds Python and dependencies; [current PyPI metadata](https://pypi.org/project/dmgbuild/) requires Python 3.10+. A PKG is simply a file in its content list. |
| [appdmg / LinusU/node-appdmg](https://github.com/LinusU/node-appdmg) | MIT Node tool with a declarative JSON layout: files, positions, background, window, filesystem, compression, and DMG signing. | Capable generic container for our PKG; useful if we wanted JSON configuration. Adds a Node toolchain without a compelling advantage for this repository. Notarization is not among its documented configuration options. |
| [sindresorhus/create-dmg](https://github.com/sindresorhus/create-dmg) | A separate MIT Node tool focused on making an attractive app DMG automatically; generates a disk icon and can sign the image. Current README requires Node 20+. | Deliberately opinionated, with an `.app`-oriented command and few layout controls. Weak fit for a Suite PKG carrier. Do not confuse this npm package with the shell project above. Its README calls out notarization as a separate task. |

Maintenance evidence is a snapshot, not a guarantee of support: the shell project's [release page](https://github.com/create-dmg/create-dmg/releases) lists v1.3.0 and recent work on AppleScript timing and path handling. dmgbuild's [PyPI release](https://pypi.org/project/dmgbuild/) is 1.6.7, uploaded 2026-01-15. appdmg's [repository](https://github.com/LinusU/node-appdmg) lists latest GitHub release 0.6.6 dated 2023-02-03; that does not prove there have been no later commits. Sindre's [release page](https://github.com/sindresorhus/create-dmg/releases) lists v8.1.0, including an updated macOS 26 disk icon. Where GitHub's rendered date omits the year, this note deliberately does not infer one.

**CLI shortlist:** try the shell create-dmg if minimizing toolchain additions is the priority; compare dmgbuild if automated Finder styling becomes fragile. This is a fit judgment from the documented designs, not a benchmark. Neither should replace Folio's payload/version validation or clean-install proof. Keep package construction and the outer DMG presentation as separate steps so either can change independently.
