# ``ComposerKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The domain framework for Folio Composer's Arrangements, including Editions.

## Overview

ComposerKit owns publication meaning and adapts it to the independent TypographyKit engine. Document authority remains with the host. The current public operation is a bounded composition preview; Arrangement persistence, Editions, Production Configurations, coordinated Streams and output generation remain future capabilities.

## Controlled preview

A ``PublicationPreviewInput`` identifies caller-owned source text and supplies exact UTF-16 line breaks and a width. ``ComposerPreview/compose(_:)`` adapts it to TypographyKit with the preview's fixed Latin, left-to-right Times typography. The returned immutable result retains source identity, geometry and structured diagnostics. Its drawing uses the same result that supplies those relationships.

``CompositionPreviewView`` is a reusable AppKit canvas, loaded by ComposerKit's `Preview.storyboard`. Call ``CompositionPreviewWindow/makeWindowController(input:)`` on the main actor to create its window with caller-owned input. The canvas visibly and accessibly distinguishes complete, unsupported and infeasible results. Composer's initial window displays a controlled specimen through this public interface; it does not open or save an Arrangement.

## Public interface and hosting

Use `import ComposerKit`. The owning application uses the same public interface as other hosts. AppKit presentation is main-actor isolated; the composition adapter is synchronous. TypographyKit retains neutral text shaping and geometry without acquiring Folio objects or storage. Apps and Kits ship as one coordinated Suite version.

The public declarations and their DocC comments are in `Interface/ComposerPreview.swift`,
`Interface/CompositionPreviewView.swift`, and `Interface/CompositionPreviewWindow.swift`.

## Topics

### Preview

- ``PublicationPreviewInput``
- ``ComposerPreview``
- ``CompositionPreviewView``
- ``CompositionPreviewWindow``
