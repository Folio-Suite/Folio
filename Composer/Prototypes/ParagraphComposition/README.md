<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Native paragraph composition prototype

Throwaway experiment for [issue #22](https://github.com/Folio-Suite/Folio/issues/22),
following [ADR 0012](../../../docs/adr/0012-semantic-publication-and-native-composition.md).
It compares complete justified paragraphs through TextKit 2 and Core Text. The
application targets and ComposerKit are unchanged.

## Run

On a Mac with Xcode selected:

```sh
ruby Composer/Prototypes/ParagraphComposition/run.rb
```

An optional first argument selects another output directory. The default is
`build/results` beside this README, ignored by Git. The runner compiles the
Objective-C executable, renders fixtures with Times and the supplied OTF faces,
and records the OS, Xcode/SDK versions and input hashes in `run.json`. The first
run downloads checksum-pinned font archives from CTAN; later runs use the cache.
Open `build/results/comparison.html` for the self-contained visual comparison.

Each font run has a `results.json` and PNGs for all specimens at 12 pt, widths of
240, 300 and 360 pt, with requested hyphenation off and on. Font registration is
limited to the experiment process. Nothing is installed into Font Book.

## Review question

Does native paragraph composition give acceptable typographic color on these
specimens, and which failures would justify a custom break-selection experiment?

Inspect complete paragraphs for loose lines, abrupt changes in word spacing,
rivers, repeated hyphens and short final lines. Compare the same specimen, font,
width and hyphenation request across engines. Preserve the line records with
the images so attractive output remains traceable to its inputs.

Line breaks are observable evidence. They do not identify Apple's private
algorithm or prove a global optimum. Matching requested settings does not prove
identical engine behavior, especially for hyphenation. Font variants retain
their own names and provenance; Latin Modern and Computer Modern Unicode are
separate test inputs.

This experiment does not evaluate editing/selection integration, coordinated
Streams, page optimization, publication conformance or runtime performance of
a production engine. Human review of typographic quality remains necessary.

See [fixture sources](fixtures/sources.md) and [font sources](fonts.md) for provenance.

## CLI checks

After running the experiment:

```sh
PARAGRAPH_COMPOSITION_BINARY="$PWD/Composer/Prototypes/ParagraphComposition/build/results/paragraph-composition" \
  ruby Composer/Prototypes/ParagraphComposition/cli_test.rb
```

These check rejected empty/duplicate identifiers, an empty specimen list, complete
Unicode paragraph coverage, PNG output and repeatable line-break records. They
do not assign a typography quality score.
