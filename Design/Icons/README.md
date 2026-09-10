<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Folio glass icons

Open `Write.icon` or `Research.icon` in Apple's Icon Composer. These are editable native icon packages, with SVG assets and appearance/material settings in `icon.json`. They are a vector interpretation of the approved vaporwave concept, not a pixel-identical conversion of the generated illustration.

Write uses a glass fountain-pen nib. Research uses a glass open book, with independent cover and page layers. Both share a gradient sky, setting sun, and horizon reflections. Default and Dark have explicit artwork and background overrides; Mono uses Icon Composer's automatic treatment and has not received a separate design pass.

Layers are listed front to back. The foreground group applies native specular highlights, translucency, blur material, and shadow. The sunset layers disable glass effects to keep the background quiet. Every source SVG uses a 1024 × 1024 canvas. Gradients live in the SVGs, while Icon Composer controls the materials.

`Previews/Write.png` and `Previews/Research.png` are the 256-pixel default renditions extracted from Apple's compiled `.icns` output. Inspect the packages themselves for the live material effects and Dark appearance. These files are not yet assigned to the application targets.

## Validation

Both packages compiled successfully with Xcode's asset compiler for macOS 26.5, producing `Assets.car`, an `.icns`, and icon metadata. Write was also inspected in Icon Composer in Default and Dark appearances. Research's compiled default rendition was visually inspected.

To compile either package for validation, create an output directory and run from the repository root, substituting `Research` for `Write` as appropriate:

```sh
xcrun actool Design/Icons/Write.icon \
  --compile /tmp/folio-icon-compile-write \
  --platform macosx --minimum-deployment-target 26.5 \
  --app-icon Write \
  --output-partial-info-plist /tmp/folio-icon-compile-write/Info.plist
```

See [Apple's Icon Composer guidance](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) for editing and adding the package to an Xcode target.
