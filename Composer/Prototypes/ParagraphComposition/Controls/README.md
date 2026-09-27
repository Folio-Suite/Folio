<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Composition control probes

These throwaway probes extend issue #22's visual baseline with the three control
questions requested on 27 September 2026. They exercise TextKit 2's native
composer and caller-controlled Core Text composition independently. They do not
select a production architecture.

## Run and inspect

From the repository root:

```sh
ruby Composer/Prototypes/ParagraphComposition/Controls/run.rb
```

This compiles both standalone programs with warnings treated as errors and writes
JSON, binaries, and PNGs beneath ignored `build/`. An optional output
directory is accepted. The runner rejects incomplete TextKit 2 source coverage;
unmet capability contracts remain in the report as experimental results.

Read [the comparison and recommendation](FINDINGS.md), then the detailed
[TextKit 2 notes](textkit-notes.md) and [Core Text notes](coretext-notes.md).
The checked-in `*-results.json` files and `run-evidence.json` capture the reviewed
run; the latter records source and result hashes. Selected images are
retained in `evidence/`. These results were measured on macOS 27 and do not
establish behavior on Folio's oldest supported OS.

## Required distinctions

- **Candidate generation:** identify legal break opportunities from language
  rules, exceptions, and document semantics.
- **Break selection:** choose a complete sequence from those opportunities.
- **Line realization:** shape and position the selected text, discretionary
  material, spacing and edge adjustments.
- **Validation:** detect impossible or violated constraints; never report a
  forbidden break, missing character or overflow as successful composition.

A supplied soft hyphen alone tests candidate input. A prescribed break sequence
tests selection control. Neither establishes that the candidate is linguistically
correct or that the selected sequence is typographically optimal.

## Contracts

| Area | Required observation |
| --- | --- |
| Hyphenation | With automatic hyphenation disabled, supplied discretionary opportunities can be selected or vetoed. Inspect actual breaks and displayed hyphens, not only requested settings. |
| Break enforcement | A feasible prescribed sequence is produced without adding hard breaks to the canonical paragraph. An impossible request produces a detectable failure or overfull result rather than an unreported policy violation. |
| Source integrity | Line ranges cover the source, discretionary output has an explicit source relationship, and breaks inside a composed character are rejected where the caller owns break selection. |
| Tracking | In `HHHH`, adding 0.5 pt of tracking increases the first-to-fourth glyph-origin distance by 1.5 pt. Record caret coordinates separately; insertion boundaries can use different spacing conventions. This isolates a controlled, simple four-cluster case. |
| Expansion | Measure 0.98/1.00/1.02 horizontal font transforms. Distinguish a supported fixed transform from a composer choosing expansion jointly with line breaks. |
| Punctuation | Measure native hanging-punctuation options where exposed, and a requested protrusion amount where caller-owned positioning is possible. Distinguish native edge rules from arbitrary per-character rules. |

All probes use Times-Roman at 12 pt and record OS, SDK and actual font metadata.
Synthetic words and controlled discretionary positions test mechanisms, not a
language dictionary. No imported TeX matcher is claimed here.

The Core Text probe measures that tracking contract through glyph positions.
The TextKit 2 probe measures line width and caret positions; direct glyph-origin
verification remains outside that probe.

## Scope of a passing result

A pass applies to the recorded input, control and geometry. The probes do not
establish whole-paragraph optimization, optimal typographic color, reliable
pagination, a mathematical formula engine, or correctness for every script.
Production policy still requires tests for contextual shaping at breaks,
combining marks, bidirectional text, exceptional spelling changes, fonts with
appropriate coverage, and editable source-to-layout mappings.

Core Text cases that choose ranges, add discretionary output, or position glyphs
are explicitly Folio-owned composition built on Core Text. Drawing a custom
Core Text composition inside a TextKit 2 fragment would demonstrate hosting,
not that TextKit 2's native composer implements the same policy.
