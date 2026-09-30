<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio

A native macOS Suite for creating and publishing complex, technical, or large-scale Works.

Open `Folio.xcworkspace`. This monorepo contains the Write, Research, and Composer applications; four domain frameworks built by `Core/Core.xcodeproj`; and standalone UndoKit and TypographyKit frameworks. The app and domain-Kit ports are now Swift. TypographyKit provides a bounded controlled-composition API, with a small ComposerKit preview integration; full paragraph optimization and publication workflows remain future work. UndoKit is imported with its [upstream provenance](UndoKit/UPSTREAM.md) and [dated design inventory](UndoKit/docs/imported-design/README.md); durable history is not implemented. The approved Core framework structure is recorded in [ADR 0016](docs/adr/0016-core-framework-project.md). The [migration handoff](docs/plans/accepted-backlog.md) tracks integrated validation and later capabilities. The [migration acceptance record](docs/verification/swift-migration-acceptance.md) records passing signed native verification and the maintainer’s pre-alpha acceptance, including temporary Sonoma and installation waivers. Intel runtime remains unverified.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout, build, test, namespace, and contribution workflows, and the [documentation guide](docs/README.md) for current contracts, implementation notes, and dated research. Write has a first native text editor with Core Data Work packages; see [its implementation notes](docs/architecture/native-work-v1.md). The applications remain experimental, and cross-application Work Session ownership and archival exchange remain separate work against the contracts in `docs/architecture/`.

The [current library layout](docs/architecture/current-library-layout.md) describes the framework targets, source ownership, and explicit public interfaces.

The adopted [Cocoa Suite direction](docs/adr/0009-continue-cocoa-suite-with-domain-kits.md) maps Work to Write, Source Library to Research, and Edition to Composer. Kits supply domain capabilities; owning hosts will provide shared editing services. Composer now has a bounded typography preview, while saved Arrangements, production output, and shared-domain hosting remain future work. A possible Folio utility would provide focused Project operations, potentially installed alongside FolioKit. Its scope and the management of small helper apps remain [future design work](docs/plans/swift-migration-and-suite-roadmap.md#small-utilities-and-full-suite-applications).

The [composition and publication contract](docs/architecture/composition-publication-contract.md) defines Composer's WYSIWYM direction: reusable page templates, coordinated text Streams, user-authored Profiles and Themes, and a native engine built on Apple's typography facilities. Its [paragraph-composition research](docs/research/2026-09-26-native-paragraph-composition.md) and staged experiments distinguish available APIs from capabilities still to be proven.

The current [document file types](docs/document-file-types.md) distinguish each app’s
native Document from its ZIP Archive. Write and Research support native document
editing; ZIP handling and Composer’s new document format remain reserved. See
[icon sources](Design/Icons/README.md) for the shared visual identity.

## AI-assisted development

Folio uses [Matt Pocock's engineering skills](https://github.com/mattpocock/skills) for architecture, domain modeling, research, implementation, and review. His work is a substantial part of our development workflow. These skills are installed globally for consistency across projects; Folio-specific Cocoa adaptations live in this repository. See [AI skill usage and attribution](docs/ai-skills.md) for the setup, other contributors, and retained source notices.

## License

Copyright © 2026 the Folio Project. Licensed under the [MIT License](LICENSE).
