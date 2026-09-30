<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Make Swift interfaces and resources easy to discover

Accepted by the maintainer on 2026-09-30. Organize apps, frameworks, and libraries so a reader can understand their entry points and public contract before descending into implementation folders. Human readers learn a codebase incrementally; discovering an interface should not require reading the entire module. This supplements [ADR 0015](0015-swift-suite-and-independent-frameworks.md) and applies across the Suite, TypographyKit, and UndoKit.

## Public interfaces and entry points

Keep public types, protocols, initializers, methods, and properties in one clearly named interface file or a small, predictable set of files grouped by capability. Keep their DocC comments beside the declarations. Identify those files in the module's README or DocC overview so readers have an obvious starting point. Larger interfaces may use an `Interface/` folder; a single oversized file is not the goal.

These files contain the actual Swift declarations. Use extensions and internal implementation types where useful, while respecting Swift's rules for stored properties, access control, and type declarations. Small implementations may remain beside their public declarations; avoid duplicating signatures or adding forwarding layers solely to imitate a header. Swift visibility and module boundaries remain authoritative; this convention requires no authored module map or umbrella header.

Keep each app's `AppDelegate.swift` at the app source root, visible as its entry point, and use `@main` for the AppKit application entry point. Collect implementation areas under a top-level `Modules/` directory, with capability folders such as `Modules/History/` or `Modules/Document/`. Keep `Interface/` and `Resources/` alongside `Modules/`, so readers can inspect the contract and bundled resources before descending into implementation. These module folders organize source; they do not by themselves create Swift targets or separate libraries.

Each module should ideally group cohesive code that could stand alone as its own library if extracted later. Choose boundaries with a clear responsibility, a defined interface, and explicit dependencies on other modules or the enclosing product. Use that potential library boundary to guide organization without requiring a separate target today.

## Resources and future libraries

Keep an app or framework's resources at its source root or collected in one top-level `Resources/` directory. Organize that directory by purpose as needed, rather than scattering assets, storyboards, models, and other bundled files through implementation folders. A single resource file may remain at the root when that is sufficient. Preserve platform-required locations and formats.

The enclosing app or framework owns those bundled resources and their lookup. If implementation folders later become internal libraries, keep those libraries as implementation components of the enclosing product and retain resource ownership there. Pass resource access into an extracted library where necessary. Folder extraction alone does not establish an independently distributed framework or a new resource bundle; those changes require an explicit architectural decision. Existing independent framework boundaries remain as defined in ADR 0015.

Apply this convention to new code and focused reorganizations. This ADR records the style decision; it does not claim that all existing source and resource layouts have already been converted.
