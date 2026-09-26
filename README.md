<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio

A native macOS Suite for creating and publishing complex, technical, or large-scale Works.

Open `Folio.xcworkspace`. This monorepo contains FolioKit, Write, Research, and Composer, together with shared architecture and build configuration.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout, build, test, namespace, and contribution workflows. Write has a first native text editor with Core Data Work packages; see [its implementation notes](docs/architecture/native-work-v1.md). The applications remain experimental, and cross-application Work Session ownership and archival exchange remain separate work against the contracts in `docs/architecture/`.

The [current library layout](docs/architecture/current-library-layout.md) describes how implementation sources compile into the Kits behind explicit public interfaces.

The adopted [Cocoa Suite direction](docs/adr/0009-continue-cocoa-suite-with-domain-kits.md) maps Work to Write, Source Library to Research, and Edition to Composer. Kits supply domain capabilities; owning hosts will provide shared editing services. Composer is currently a skeleton, and the domain-host service topology remains to be implemented.

## AI-assisted development

Folio uses [Matt Pocock's engineering skills](https://github.com/mattpocock/skills) for architecture, domain modeling, research, implementation, and review. His work is a substantial part of our development workflow. These skills are installed globally for consistency across projects; Folio-specific Cocoa adaptations live in this repository. See [AI skill usage and attribution](docs/ai-skills.md) for the setup, other contributors, and retained source notices.

## License

Copyright © 2026 the Folio Project. Licensed under the [MIT License](LICENSE).
