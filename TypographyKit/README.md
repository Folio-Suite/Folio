<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# TypographyKit

TypographyKit is an independent Foundation, Core Text, and Core Graphics
framework for text measurement and composition. It has no FolioKit, domainKit,
or AppKit dependency. ComposerKit owns publication meaning and adapts its domain
inputs to TypographyKit.

This directory is a framework scaffold. It does not yet provide composition
behavior or claim typography correctness. The future public operation is
intended to accept owned immutable inputs and return geometry, source mappings,
and diagnostics. Its supported text and composition behavior remains to be
implemented and verified.

## Build

From this directory, build the standalone framework with:

```sh
xcodebuild -project TypographyKit.xcodeproj -scheme TypographyKit -destination 'platform=macOS' build
```

The framework targets macOS 14 in Swift 6 language mode. A successful scaffold build
checks project integration only; it does not demonstrate typography correctness
or the foundation acceptance described in the Suite roadmap.

`Project.xcconfig` provides standalone version defaults and optionally inherits
the enclosing Suite's version configuration. The shared scheme can also archive
the framework. No stable external API or separately versioned binary release is
published by this scaffold.
