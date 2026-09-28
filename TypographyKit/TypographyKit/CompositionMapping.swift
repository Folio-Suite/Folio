// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

private struct MappingBuilder {
    let sourceUnits: [SourceUnit]
    let sourceCount: Int
    var text = ""
    var mappings: [SourceMapping] = []

    mutating func appendSource(_ fragment: String, range: NSRange) {
        let renderedStart = (text as NSString).length
        text += fragment
        var offset = range.location
        while offset < range.location + range.length {
            let identity = sourceUnits[offset]
            var next = offset + 1
            while next < range.location + range.length &&
                sourceUnits[next].occurrenceIndex == identity.occurrenceIndex {
                next += 1
            }
            mappings.append(SourceMapping(
                occurrenceIndex: identity.occurrenceIndex,
                sourceID: identity.sourceID,
                sourceRange: NSRange(location: identity.localOffset, length: next - offset),
                renderedRange: NSRange(
                    location: renderedStart + offset - range.location,
                    length: next - offset
                ),
                kind: .source
            ))
            offset = next
        }
    }

    mutating func appendMaterial(_ material: String, range: NSRange, kind: MappingKind, anchor: Int) {
        let renderedStart = (text as NSString).length
        text += material
        let identity = sourceUnits[min(kind == .inserted ? anchor : range.location, sourceCount - 1)]
        mappings.append(SourceMapping(
            occurrenceIndex: identity.occurrenceIndex,
            sourceID: identity.sourceID,
            sourceRange: NSRange(location: identity.localOffset, length: range.length),
            renderedRange: NSRange(location: renderedStart, length: (material as NSString).length),
            kind: kind
        ))
    }
}

extension CompositionEngine {
    func renderLine(from start: Int, to end: Int) throws -> RenderedLine {
        var builder = MappingBuilder(sourceUnits: sourceUnits, sourceCount: sourceCount)
        if let previous = request.discretionaries.first(where: { $0.boundary == start }),
           selected.contains(start), !previous.afterBreak.isEmpty {
            builder.appendMaterial(
                previous.afterBreak,
                range: NSRange(location: start, length: 0),
                kind: .inserted,
                anchor: start
            )
        }
        var cursor = start
        let active = request.discretionaries
            .filter { $0.boundary > start && $0.boundary <= end }
            .sorted { $0.boundary < $1.boundary }
        for disc in active {
            let range = disc.replacementRange
            guard range.location >= cursor else {
                throw CompositionIssue(
                    .unsupported, .unsupportedControl,
                    "Discretionary crosses a line boundary.", offset: disc.boundary
                )
            }
            if cursor < range.location {
                appendSource(from: cursor, to: range.location, into: &builder)
            }
            let material = selected.contains(disc.boundary) ? disc.beforeBreak : disc.noBreak
            let kind: MappingKind = range.length == 0 ? .inserted :
                (material.isEmpty ? .omitted : .substituted)
            let anchor = selected.contains(disc.boundary) ? disc.boundary - 1 : disc.boundary
            builder.appendMaterial(material, range: range, kind: kind, anchor: anchor)
            cursor = disc.boundary
        }
        if cursor < end {
            appendSource(from: cursor, to: end, into: &builder)
        }
        guard !builder.text.isEmpty else {
            throw CompositionIssue(
                .unsupported, .unsupportedControl,
                "Empty rendered lines are unsupported.", offset: start
            )
        }
        return RenderedLine(
            text: builder.text,
            sourceRange: NSRange(location: start, length: end - start),
            mappings: builder.mappings
        )
    }

    private func appendSource(from start: Int, to end: Int, into builder: inout MappingBuilder) {
        let range = NSRange(location: start, length: end - start)
        builder.appendSource((source as NSString).substring(with: range), range: range)
    }
}
