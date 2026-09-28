<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Optional paragraph composition fonts

The prototype can use two separately sourced serif faces. They are optional
local inputs: run `sh Composer/Prototypes/ParagraphComposition/fonts/fetch-fonts.sh`
from the repository root. The script puts the requested OTFs and their original
license texts in `fonts/.build/inputs/`, an ignored build cache. It does not
install fonts globally. Point the native harness at this directory explicitly.

| Variant | File | PostScript name | Upstream/version |
| --- | --- | --- | --- |
| Latin Modern Roman 12 Regular | `fonts/.build/inputs/lmroman12-regular.otf` | `LMRoman12-Regular` | Latin Modern 2.005, CTAN `fonts/lm` |
| Computer Modern Unicode Serif Roman | `fonts/.build/inputs/cmunrm.otf` | `CMUSerif-Roman` | CM Unicode 0.7.0, CTAN `fonts/cm-unicode` |

The second variant is the Computer Modern Unicode (CMU) conversion of
METAFONT-derived outlines into OpenType, not Knuth's original METAFONT face.
CTAN describes CMU as converted from METAFONT sources using mftrace and
FontForge, and identifies the package as version 0.7.0.

## Provenance and licenses

* Latin Modern: [CTAN package and archive](https://ctan.org/tex-archive/fonts/lm)
  (version 2.005; copyright 2003–2021 B. Jackowski and J. M. Nowacki).
  The focused source is the archive member
  `fonts/opentype/public/lm/lmroman12-regular.otf`. Its upstream license is
  [GUST Font License](https://www.gust.org.pl/projects/e-foundry/licenses),
  copied verbatim beside the staged font as `GUST-FONT-LICENSE.TXT`.
* Computer Modern Unicode: [CTAN package and archive](https://ctan.org/tex-archive/fonts/cm-unicode)
  (version 0.7.0; authors Andrey Panov and Nikola Lečić). The focused source is
  `cm-unicode/fonts/otf/cmunrm.otf`; its upstream license is the
  SIL Open Font License 1.1, copied verbatim as `OFL.txt`.

The reproducible source URLs are:

* `https://mirrors.ctan.org/fonts/lm.zip`
* `https://mirrors.ctan.org/fonts/cm-unicode.zip`

The exact archive SHA-256 values are pinned and checked by the script:

| Archive | SHA-256 |
| --- | --- |
| `lm.zip` | `71c48809cb50fbfe09c8eddaa251398957c7b243acdf69f7f807268f0d42c939` |
| `cm-unicode.zip` | `9631fe99640da97875755db86cbb85fe99bd06526b65f0c42b4df266e1091af0` |

It also records the archive hashes in `fonts/.build/SHA256SUMS` and the
selected font/license hashes in `fonts/.build/INPUTS-SHA256SUMS`. The GUST
license applies the LPPL and its names-change clause is expressly a request,
not a legal requirement. CMU is distributed under OFL 1.1; its copyright and
license notice accompany the unmodified font. Neither font is sold separately.

No unrelated font faces are staged by the script.
