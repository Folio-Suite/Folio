<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Distribute Folio as an integrated suite

Folio is one comprehensive product, not a family of applications sold or installed piecemeal. Its primary distribution will be a signed and notarized installer package delivered in a disk image, allowing the suite and its integrations to be installed, versioned, updated, and supported coherently.

## Consequences

The directly distributed Suite defines Folio's architecture and complete capability set. A Mac App Store edition may be developed as a secondary distribution profile if Folio can remain coherent within sandboxing, packaging, automation, and review constraints; App Store compatibility will not constrain the primary Suite or require its constituent applications to become separate products.

Under [issue #15](https://github.com/Folio-Suite/Folio/issues/15), traditional deployment is intended to install shared frameworks, with applications exposing domain services implemented by their Kits. Physical installation layout is separate from module ownership. Framework locations, compatible versions, signing, resource resolution, service discovery, and updates need a clean-install proof. Sandboxing and App Store delivery remain options to evaluate independently; neither is established by shared code or assumed to use the traditional installation layout unchanged.
