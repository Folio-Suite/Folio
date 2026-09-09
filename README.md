<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio

A native macOS Suite for creating and publishing complex, technical, or large-scale Works.

Open `Folio.xcworkspace`. This monorepo contains FolioKit, Write, and Research, together with shared architecture and build configuration.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout, build, test, namespace, and contribution workflows. Write has a first native text editor with Core Data Work packages; see [its implementation notes](docs/architecture/native-work-v1.md). The applications remain experimental, and cross-application Work Session ownership and archival exchange remain separate work against the contracts in `docs/architecture/`.

The [current library layout](docs/architecture/current-library-layout.md) describes how the editor implementation is divided among the existing dynamic libraries and exposed through FolioKit and WriteKit.

## License

Copyright © 2026 the Folio Project. Licensed under the [MIT License](LICENSE).
