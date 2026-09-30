// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import Foundation
import TypographyKit

@main struct CompositionBehavior {
    static func request(
        _ text: String,
        breaks: [Int]? = nil,
        adjustments: CompositionAdjustments = .init(),
        width: CGFloat = 200,
        discretionaries: [Discretionary] = []
    ) -> CompositionRequest {
        CompositionRequest(
            occurrences: [.init(sourceID: "source", text: text)],
            fontPostScriptName: "Times-Roman",
            fontSize: 12,
            lineWidth: width,
            lineHeight: 16,
            breaks: breaks ?? [(text as NSString).length],
            discretionaries: discretionaries,
            adjustments: adjustments
        )
    }

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() {
        checkDiscretionariesAndMappings()
        checkInvalidInputsAndConstraints()
        checkAdjustmentGeometry()
        checkRepeatedOccurrencesAndDrawing()
        print("TypographyKit public composition behavior passed")
    }

    private static func checkDiscretionariesAndMappings() {
        let exact = TypographyComposer.compose(request("extraordinary", breaks: [5, 13]))
        check(exact.status == .complete, "exact break status")
        check(exact.lines.map(\.renderedText) == ["extra", "ordinary"], "exact breaks")
        check(
            exact.lines.map(\.sourceRange) == [NSRange(location: 0, length: 5), NSRange(location: 5, length: 8)],
            "source coverage"
        )
        check(exact.provenance.actualFonts == ["Times-Roman"], "actual font")

        let discretionary = TypographyComposer.compose(
            request("extraordinary", breaks: [5, 13], discretionaries: [
                .init(
                    boundary: 5,
                    replacementRange: NSRange(location: 5, length: 0),
                    beforeBreak: "-"
                ),
            ])
        )
        check(discretionary.status == .complete, "discretionary status")
        check(discretionary.originalText == "extraordinary", "original retained")
        check(discretionary.lines.map(\.renderedText) == ["extra-", "ordinary"], "selected discretionary")
        check(
            discretionary.lines[0].mappings.contains {
                $0.kind == .inserted && $0.renderedRange.length == 1
            },
            "inserted mapping"
        )

        let replacements = checkReplacementMappings()
        checkMappingCoverage([exact, discretionary] + replacements)
        checkUnselectedDiscretionary()
    }

    private static func checkReplacementMappings() -> [CompositionResult] {
        let substituted = TypographyComposer.compose(
            request("extraordinary", breaks: [5, 13], discretionaries: [
                .init(
                    boundary: 5,
                    replacementRange: NSRange(location: 4, length: 1),
                    beforeBreak: "a-",
                    noBreak: "a"
                ),
            ])
        )
        check(substituted.originalText == "extraordinary", "substitution retains original")
        check(substituted.lines[0].renderedText == "extra-", "substituted before break")
        check(
            substituted.lines[0].mappings.contains {
                $0.kind == .substituted && $0.sourceRange.length == 1
            },
            "substitution mapping"
        )

        let omitted = TypographyComposer.compose(
            request("extraordinary", breaks: [5, 13], discretionaries: [
                .init(
                    boundary: 5,
                    replacementRange: NSRange(location: 4, length: 1),
                    beforeBreak: "",
                    noBreak: "a"
                ),
            ])
        )
        check(
            omitted.lines[0].mappings.contains {
                $0.kind == .omitted && $0.renderedRange.length == 0
            },
            "omission mapping"
        )
        return [substituted, omitted]
    }

    private static func checkMappingCoverage(_ results: [CompositionResult]) {
        for result in results {
            for line in result.lines {
                check(
                    line.mappings.reduce(0) { $0 + $1.sourceRange.length } == line.sourceRange.length,
                    "each source unit covered once"
                )
                check(
                    line.mappings.reduce(0) { $0 + $1.renderedRange.length }
                        == (line.renderedText as NSString).length,
                    "each rendered unit mapped once"
                )
            }
        }

    }

    private static func checkUnselectedDiscretionary() {
        let unselected = TypographyComposer.compose(
            request("extraordinary", discretionaries: [
                .init(
                    boundary: 5,
                    replacementRange: NSRange(location: 5, length: 0),
                    beforeBreak: "-",
                    noBreak: ""
                ),
            ])
        )
        check(unselected.lines[0].renderedText == "extraordinary", "unselected discretionary")
    }

    private static func checkInvalidInputsAndConstraints() {
        let invalid = TypographyComposer.compose(request("a\u{301}b", breaks: [1, 3]))
        check(
            invalid.status == .unsupported && invalid.diagnostics[0].code == .invalidBoundary,
            "grapheme boundary"
        )

        let overfull = TypographyComposer.compose(request("MMMMMMMM", width: 20))
        check(
            overfull.status == .infeasible && overfull.diagnostics.contains { $0.code == .overfullLine },
            "overfull result"
        )

        let constrained = TypographyComposer.compose(
            .init(
                occurrences: [.init(sourceID: "source", text: "AB")],
                fontPostScriptName: "Times-Roman",
                fontSize: 12,
                lineWidth: 200,
                lineHeight: 16,
                breaks: [2],
                requiredBreaks: [1]
            )
        )
        check(
            constrained.status == .infeasible && constrained.lines.isEmpty,
            "required break"
        )

        let missingFont = TypographyComposer.compose(
            .init(
                occurrences: [.init(sourceID: "source", text: "AB")],
                fontPostScriptName: "NoSuchFont-392840",
                fontSize: 12,
                lineWidth: 200,
                lineHeight: 16,
                breaks: [2]
            )
        )
        check(
            missingFont.status == .unsupported && missingFont.diagnostics[0].code == .fontUnavailable,
            "unavailable font"
        )
    }

    private static func checkAdjustmentGeometry() {
        let plainTracking = TypographyComposer.compose(request("HHHH"))
        let tracked = TypographyComposer.compose(request("HHHH", adjustments: .init(tracking: 0.5)))
        let trackingDelta = tracked.lines[0].glyphs[3].position.x - plainTracking.lines[0].glyphs[3].position.x
        check(abs(trackingDelta - 1.5) < 0.1, "Core Text tracking fixture")

        let narrow = TypographyComposer.compose(
            request("Harmonious", adjustments: .init(horizontalExpansion: 0.98, expansionLimits: 0.98...1.02))
        )
        let normal = TypographyComposer.compose(request("Harmonious"))
        let wide = TypographyComposer.compose(
            request("Harmonious", adjustments: .init(horizontalExpansion: 1.02, expansionLimits: 0.98...1.02))
        )
        check(abs(narrow.lines[0].advance - normal.lines[0].advance * 0.98) < 0.1, "narrow expansion")
        check(abs(wide.lines[0].advance - normal.lines[0].advance * 1.02) < 0.1, "wide expansion")

        let quote = TypographyComposer.compose(request("“Quoted words”"))
        let protruded = TypographyComposer.compose(
            request("“Quoted words”", adjustments: .init(leadingProtrusion: 2.5))
        )
        check(
            abs(protruded.lines[0].glyphs[0].position.x - quote.lines[0].glyphs[0].position.x + 2.5) < 0.01,
            "quote shifted"
        )
        check(
            abs(protruded.lines[0].glyphs[1].position.x - quote.lines[0].glyphs[1].position.x) < 0.01,
            "interior fixed"
        )

        let spaced = TypographyComposer.compose(request("A B", adjustments: .init(spaceAdjustment: 1)))
        let base = TypographyComposer.compose(request("A B"))
        check(abs(spaced.lines[0].advance - base.lines[0].advance - 1) < 0.01, "space advance")
        check(
            abs(spaced.lines[0].glyphs[2].position.x - base.lines[0].glyphs[2].position.x - 1) < 0.01,
            "space position"
        )
    }

    private static func checkRepeatedOccurrencesAndDrawing() {
        let repeated = TypographyComposer.compose(
            .init(
                occurrences: [
                    .init(sourceID: "same", text: "Hi"),
                    .init(sourceID: "same", text: "Hi"),
                ],
                fontPostScriptName: "Times-Roman",
                fontSize: 12,
                lineWidth: 200,
                lineHeight: 16,
                breaks: [4]
            )
        )
        check(repeated.lines[0].mappings.count == 2, "repeat mapping count")
        check(repeated.lines[0].mappings.map(\.occurrenceIndex) == [0, 1], "repeat occurrence identity")

        let context = CGContext(
            data: nil,
            width: 200,
            height: 60,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let exact = TypographyComposer.compose(request("extraordinary", breaks: [5, 13]))
        exact.draw(in: context, at: CGPoint(x: 5, y: 35))
        check(context.makeImage() != nil, "draw result")
    }
}
