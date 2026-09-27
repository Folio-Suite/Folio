<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio icons

## App icons

The authoritative editable Icon Composer packages live in the app targets:

- `Write/Write/AppIcon.icon`: amber nib with a cutout slit and engraving.
- `Research/Research/AppIcon.icon`: violet book with page-text detail.
- `Composer/Composer/AppIcon.icon`: cobalt page pair with cyan/teal layout regions.

Edit colors, materials, appearance variants, and scale in Icon Composer. The
layer fill specializations determine displayed colors; SVGs supply the shapes.
The quiet automatic background gradients and optical sizing are authored in each
package. All three targets select `AppIcon`. There are no duplicate design copies
to synchronize.

Generate disposable previews with Xcode 27's native renderer:

```sh
"$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool" \
  "$PWD/Write/Write/AppIcon.icon" --export-image \
  --output-file /tmp/Write.png --platform macOS --rendition Default \
  --width 256 --height 256 --scale 1 --design-generation 27
```

Use `Dark` or `TintedDark` for other appearances. Keep generated previews outside
the repository. Rendering and successful builds do not prove installed Dock or
Finder appearance on every supported macOS version.

## Document icons

[Document badge sources and rendering](Documents/README.md) describe the flat,
transparent artwork and optical corrections. Generated PNGs in each app's asset
catalog are shipping resources and remain checked in. `UTTypeIcons` registers the
badge; macOS supplies the document page, fold, and extension label.

## Formatting icons

`Formatting/` contains the editor formatting-symbol design sources, independent
of app and document branding.
