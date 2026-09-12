<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Semantic formatting icons

Emphasis uses an italic E; Strong Emphasis uses a bold E. Both use the macOS system font (San Francisco), outlined into custom SVG symbol assets. Baseline, cap-height, and margin guides let AppKit size and align them alongside system symbols. Static small, medium, and large variants preserve each icon’s semantic italic or bold appearance.

The editable asset entries are in `Write/WriteKit/Resources/Formatting.xcassets`. To regenerate their SVG symbol outlines from the repository root on macOS:

```sh
swift Design/Icons/Formatting/render.swift Write/WriteKit/Resources/Formatting.xcassets
```

The script uses the installed system font; a later macOS font revision may change the outlines. The committed SVGs preserve the selected design without requiring font lookup at runtime.
