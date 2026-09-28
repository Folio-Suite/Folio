// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import TypographyKit

let request = CompositionRequest(occurrences: [TextOccurrence(sourceID: "outside", text: "Hello")],
                                 fontPostScriptName: "Times-Roman", fontSize: 12,
                                 lineWidth: 120, lineHeight: 16, breaks: [5])
let result = TypographyComposer.compose(request)
precondition(result.status == .complete)
precondition(result.originalText == "Hello")
precondition(result.lines.count == 1)
precondition(result.lines[0].mappings[0].sourceID == "outside")
print("TypographyKit public consumer composed one line")
