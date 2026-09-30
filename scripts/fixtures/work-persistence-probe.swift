// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import FolioKit
import Foundation
import WriteKit

@main
struct WorkPersistenceProbe {
    static let paragraphCount = 5_000
    static let resourceBytes = 32 * 1_024 * 1_024

    @MainActor
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let mode = arguments.first else { throw ProbeError.usage }
        switch mode {
        case "setup":
            guard arguments.count == 2 else { throw ProbeError.usage }
            try setup(root: URL(fileURLWithPath: arguments[1], isDirectory: true))
        case "write":
            guard arguments.count == 4 else { throw ProbeError.usage }
            try write(source: URL(fileURLWithPath: arguments[1], isDirectory: true),
                      destination: URL(fileURLWithPath: arguments[2], isDirectory: true),
                      startedMarker: URL(fileURLWithPath: arguments[3]))
        case "verify":
            guard arguments.count == 3 else { throw ProbeError.usage }
            try verify(source: URL(fileURLWithPath: arguments[1], isDirectory: true),
                       destination: URL(fileURLWithPath: arguments[2], isDirectory: true))
        case "verify-source":
            guard arguments.count == 2 else { throw ProbeError.usage }
            try verifySource(URL(fileURLWithPath: arguments[1], isDirectory: true))
        default:
            throw ProbeError.usage
        }
    }

    @MainActor
    static func setup(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let paragraphs = (0..<paragraphCount).map { index in
            TextParagraph(identifier: .make(), runs: [TextRun(string: "Paragraph \(index): stable probe content.", emphasis: .none)])
        }
        let unit = try TextUnit(identifier: .make(), title: "Persistence probe", paragraphs: paragraphs)
        let work = Work()
        work.manuscript = try Manuscript(identifier: work.manuscriptIdentifier, units: [unit])
        let original = root.appendingPathComponent("Original.flwrbundle", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
        _ = try work.stageSave(from: nil, toEmptyPackageAt: original)
        let resource = root.appendingPathComponent("opaque-resource.bin")
        try Data().write(to: resource)
        let block = Data(repeating: 0xA5, count: 1_048_576)
        let handle = try FileHandle(forWritingTo: resource)
        defer { try? handle.close() }
        for _ in 0..<32 { try handle.write(contentsOf: block) }
        _ = try work.importResource(from: resource)
        let upgraded = root.appendingPathComponent("Upgraded.flwrbundle", isDirectory: true)
        try FileManager.default.createDirectory(at: upgraded, withIntermediateDirectories: false)
        _ = try work.stageSave(from: original, toEmptyPackageAt: upgraded)
        try FileManager.default.removeItem(at: original)
        try FileManager.default.moveItem(at: upgraded, to: original)
        print("setup paragraphs=\(paragraphCount) resourceBytes=\(resourceBytes)")
    }

    @MainActor
    static func write(source: URL, destination: URL, startedMarker: URL) throws {
        let work = try Work(contentsOf: source)
        let original = work.text.paragraphs
        var revised = original
        revised[0] = TextParagraph(identifier: original[0].identifier,
                                   runs: [TextRun(string: "Changed by persistence probe.", emphasis: .strongEmphasis)],
                                   alignment: .center)
        work.text = try TextUnit(identifier: work.text.identifier, title: work.text.title, paragraphs: revised)
        try Data("started".utf8).write(to: startedMarker)
        let began = Date()
        let report = try work.stageSave(from: source, toEmptyPackageAt: destination)
        let elapsed = Date().timeIntervalSince(began)
        print("{\"elapsedSeconds\":\(elapsed),\"changedContentUnits\":\(report.changedContentUnits),\"changedParagraphs\":\(report.changedParagraphs),\"changedRuns\":\(report.changedRuns),\"clonedStoreBytes\":\(report.clonedStoreBytes),\"copiedStoreBytes\":\(report.copiedStoreBytes),\"clonedResourceBytes\":\(report.clonedResourceBytes),\"copiedResourceBytes\":\(report.copiedResourceBytes)}")
    }

    @MainActor
    static func verify(source: URL, destination: URL) throws {
        try verifySource(source)
        if FileManager.default.fileExists(atPath: destination.path) {
            let staged = try Work(contentsOf: destination)
            guard staged.text.paragraphs.count == paragraphCount,
                  staged.text.paragraphs[0].string == "Changed by persistence probe.",
                  staged.resources.count == 1,
                  staged.resources[0].byteCount == resourceBytes else { throw ProbeError.verification("destination") }
            print("verified source=unchanged destination=updated")
        } else {
            print("verified source=unchanged destination=absent")
        }
    }

    @MainActor
    static func verifySource(_ source: URL) throws {
        let original = try Work(contentsOf: source)
        guard original.manuscript.units.count == 1,
              original.text.paragraphs.count == paragraphCount,
              original.text.paragraphs[0].string == "Paragraph 0: stable probe content.",
              original.resources.count == 1,
              original.resources[0].byteCount == resourceBytes else { throw ProbeError.verification("source") }
        print("verified source=unchanged")
    }
}

enum ProbeError: Error, CustomStringConvertible {
    case usage
    case verification(String)
    var description: String {
        switch self {
        case .usage: return "Usage: work-persistence-probe.swift setup ROOT | write SOURCE DESTINATION STARTED_MARKER | verify SOURCE DESTINATION | verify-source SOURCE"
        case .verification(let location): return "Verification failed for \(location)"
        }
    }
}
