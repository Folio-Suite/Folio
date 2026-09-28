<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio

A native macOS Suite for creating and publishing complex, technical, or large-scale Works.

Open `Folio.xcworkspace`. This monorepo contains FolioKit, Write, Research, Composer, and standalone UndoKit and TypographyKit frameworks, together with shared architecture and build configuration. UndoKit is imported with its [upstream provenance](UndoKit/UPSTREAM.md) and [dated design inventory](UndoKit/docs/imported-design/README.md); durable history is not implemented. TypographyKit is a Swift scaffold without compositor behavior. The existing Suite production code remains Objective-C; the broader Swift migration is accepted and ticketed in the [planning handoff](docs/plans/accepted-backlog.md), with implementation still ahead.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout, build, test, namespace, and contribution workflows, and the [documentation guide](docs/README.md) for current contracts, implementation notes, and dated research. Write has a first native text editor with Core Data Work packages; see [its implementation notes](docs/architecture/native-work-v1.md). The applications remain experimental, and cross-application Work Session ownership and archival exchange remain separate work against the contracts in `docs/architecture/`.

The [current library layout](docs/architecture/current-library-layout.md) describes how implementation sources compile into the Kits behind explicit public interfaces.

The adopted [Cocoa Suite direction](docs/adr/0009-continue-cocoa-suite-with-domain-kits.md) maps Work to Write, Source Library to Research, and Edition to Composer. Kits supply domain capabilities; owning hosts will provide shared editing services. Composer is currently a skeleton, and the domain-host service topology remains to be implemented. A possible Folio utility would provide focused Project operations, potentially installed alongside FolioKit. Its scope and the management of small helper apps remain [future design work](docs/plans/swift-migration-and-suite-roadmap.md#small-utilities-and-full-suite-applications).

The [composition and publication contract](docs/architecture/composition-publication-contract.md) defines Composer's WYSIWYM direction: reusable page templates, coordinated text Streams, user-authored Profiles and Themes, and a native engine built on Apple's typography facilities. Its [paragraph-composition research](docs/research/2026-09-26-native-paragraph-composition.md) and staged experiments distinguish available APIs from capabilities still to be proven.

The current [document file types](docs/document-file-types.md) distinguish each app’s
native Document from its ZIP Archive. Write and Research support native document
editing; ZIP handling and Composer’s new document format remain reserved. See
[icon sources](Design/Icons/README.md) for the shared visual identity.

## AI-assisted development

Folio uses [Matt Pocock's engineering skills](https://github.com/mattpocock/skills) for architecture, domain modeling, research, implementation, and review. His work is a substantial part of our development workflow. These skills are installed globally for consistency across projects; Folio-specific Cocoa adaptations live in this repository. See [AI skill usage and attribution](docs/ai-skills.md) for the setup, other contributors, and retained source notices.

## License

Copyright © 2026 the Folio Project. Licensed under the [MIT License](LICENSE).
