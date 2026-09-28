# ``TypographyKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

An independent Swift framework for text measurement and composition.

## Overview

TypographyKit is independent of FolioKit, Folio's domain frameworks, and AppKit. Its boundary is neutral text inputs and typography results, such as measured geometry, source mappings, and diagnostics. ComposerKit owns publication meaning and adapts its inputs to this framework.

## Current support

TypographyKit is currently an empty framework scaffold. The Swift module builds from Foundation, Core Text, and Core Graphics imports, but it defines no public types or composition operations. No typography behavior or correctness is implemented or established.

## Public interface and hosting

Swift clients can import the `TypographyKit` module, but the module currently has no public API to call. ComposerKit will use this same independent framework boundary when composition behavior is implemented.

## Limitations

The planned composition contract, supported text subset, font resolution, shaping, break realization, geometry, source mapping, diagnostics, optimization, and language coverage are not implemented or verified. Core Text availability alone does not establish those capabilities.
