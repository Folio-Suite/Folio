<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# ``TypographyKit``

An independent Foundation, Core Text, and Core Graphics framework for text
measurement and composition.

## Overview

TypographyKit is independent of FolioKit, Folio's domain Kits, and AppKit.
ComposerKit owns publication meaning and is responsible for adapting its inputs
to this framework.

The framework is currently an empty scaffold. It does not yet implement
composition behavior or establish typography correctness. The planned public
operation will accept owned immutable inputs and return geometry, mappings from
output to source content, and diagnostics. Its supported behavior and contract
remain to be implemented and verified.

## Topics

### Framework boundaries

- ComposerKit owns publication meaning and adapts domain inputs.
- TypographyKit is intended to realize text inputs as geometry with source
  mappings and diagnostics.
