// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
import Foundation
import UndoKitInterfaceProbe

struct CheckFailure: Error { let description: String }
struct SavedFixture: Codable { let request: Request; let evidence: Evidence }

@main
struct Runner {
    @MainActor
    static func check(_ condition: Bool, _ label: String) throws {
        guard condition else { throw CheckFailure(description: label) }
        print("PASS: \(label)")
    }
    static func accepted(_ result: Outcome) throws -> Evidence {
        guard case let .accepted(evidence) = result else { throw CheckFailure(description: "expected accepted") }
        return evidence
    }
    @MainActor
    static func expectFailure(_ label: String, expected: ProbeError? = nil,
                              _ operation: @MainActor () async throws -> Void) async throws {
        do { try await operation() }
        catch {
            if let expected { try check((error as? ProbeError) == expected, "\(label): correct failure") }
            else { print("PASS: \(label): failure reported") }
            return
        }
        throw CheckFailure(description: "\(label): unexpectedly succeeded")
    }
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw CheckFailure(description: "usage: write|read fixture-directory") }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        if CommandLine.arguments[1] == "write" { try await write(directory) }
        else if CommandLine.arguments[1] == "read" { try await read(directory) }
        else { throw CheckFailure(description: "unknown mode") }
    }
    @MainActor
    static func write(_ directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scope = UUID(), store = UUID()
        let host = WriteAdapter(scope: scope, resourceStore: store)
        let kitchen = KitchenAdapter(scope: UUID())
        let probe = BoundaryProbe()
        try await probe.register("folio.replace-text", endpoint: host)
        try await probe.register("kitchen.organize", endpoint: kitchen)
        let command = ReplaceText(unit: "chapter-1", replacement: "After")
        let json = try host.request(command)
        let xml = try host.request(command, codecID: "xml-plist-v1")
        let binary = try host.request(command, codecID: "binary-plist-v1")
        try check(binary.command.bytes.starts(with: Data("bplist00".utf8)), "binary codec emits a binary property list")
        try check(binary.intentFingerprint == json.intentFingerprint && binary.command.integrity != json.command.integrity,
                  "binary plist preserves host intent while changing byte representation")
        print("SIZE OBSERVATION (one small fixture, not a benchmark): JSON=\(json.command.bytes.count), XML plist=\(xml.command.bytes.count), binary plist=\(binary.command.bytes.count) bytes")
        try check(json.intentFingerprint == xml.intentFingerprint && json.command.integrity != xml.command.integrity,
                  "host intent identity stays stable across JSON/XML byte representations")
        try check(String(decoding: xml.command.bytes, as: UTF8.self).contains("<plist"), "XML codec emits a property list")
        let effect = try accepted(await probe.deliver(json))
        try check(host.text == "After" && host.applicationCount == 1, "main-actor non-Sendable model changes through public boundary")
        let details = try JSONCodec<TextEffect>().decode(effect.effect.bytes)
        try check(details.before == "Before" && details.after == "After", "accepted-effect payload differs from Command payload")
        let lookedUp = try accepted(await probe.lookup(json))
        try check(lookedUp == effect && host.applicationCount == 1, "outcome lookup does not reapply the Command")
        let undone = try accepted(await probe.compensate(operationID: json.operationID, effect: effect.effect,
                                                       scope: scope, commandID: UUID()))
        try check(host.text == "Before" && undone.effect != effect.effect, "compensation returns its own encoded effect")
        _ = try accepted(await probe.deliver(xml))
        try check(host.text == "After", "XML payload decodes and dispatches on the host actor")
        _ = try accepted(await probe.compensate(operationID: json.operationID, effect: effect.effect,
                                               scope: scope, commandID: UUID()))
        _ = try accepted(await probe.deliver(binary))
        try check(host.text == "After", "binary property-list payload decodes and dispatches on the host actor")
        let resource = try await probe.resolve(operationID: json.operationID, reference: effect.resources[0])
        try check(resource == Data("host-owned chapter asset".utf8), "host-owned resource resolves by store and object identity")
        do {
            try await expectFailure("missing host resource", expected: .missingResource) {
                _ = try await probe.resolve(operationID: json.operationID, reference: ResourceReference(store: store, key: "missing"))
            }
        }
        let frameworkResource = try await probe.frameworkFixture()
        let fixture = try JSONSerialization.jsonObject(with: frameworkResource) as? [String: Any]
        try check(fixture?["schemaVersion"] as? Int == 1, "framework fixture resolves from its resource bundle")
        let kitchenRequest = try await kitchen.request(recipeIDs: ["recipe-1", "recipe-2"], destination: "Weekend")
        let kitchenEvidence = try accepted(await probe.deliver(kitchenRequest))
        let folders = await kitchen.state()
        try check(folders == ["recipe-1": "Weekend", "recipe-2": "Weekend"], "background actor accepts intact custom-coded organization command")
        let restored = try accepted(await probe.compensate(operationID: kitchenRequest.operationID,
                                  effect: kitchenEvidence.effect, scope: kitchenRequest.scope, commandID: UUID()))
        let restoredFolders = await kitchen.state()
        try check(restoredFolders == ["recipe-1": "Inbox", "recipe-2": "Favorites"] && restored.effect != kitchenEvidence.effect,
                  "custom-command host compensates from a separately typed effect")

        let applicationsBeforeFailures = host.applicationCount
        for (label, version, codec, bytes, expected) in [
            ("unknown schema", 99, "json-v1", json.command.bytes, ProbeError.unsupportedVersion),
            ("unknown codec", 2, "missing-codec", json.command.bytes, ProbeError.unsupportedCodec),
            ("oversized bytes", 2, "json-v1", Data(repeating: 65, count: 4097), ProbeError.tooLarge)
        ] {
            let payload = Payload(typeID: json.command.typeID, version: version, codecID: codec, bytes: bytes)
            let request = Request(scope: scope, commandID: UUID(), operationID: json.operationID,
                                  intentFingerprint: "fixture", command: payload)
            try await expectFailure(label, expected: expected) { _ = try await probe.deliver(request) }
            try check(request.command.bytes == bytes, "\(label): original bytes retained")
        }
        let badXML = Request(scope: scope, commandID: UUID(), operationID: json.operationID,
                             intentFingerprint: "fixture", command: Payload(typeID: json.command.typeID,
                             version: 2, codecID: "xml-plist-v1", bytes: Data("<broken".utf8)))
        try await expectFailure("malformed XML property list") { _ = try await probe.deliver(badXML) }
        let badBinary = Request(scope: scope, commandID: UUID(), operationID: json.operationID,
                                intentFingerprint: "fixture", command: Payload(typeID: json.command.typeID,
                                version: 2, codecID: "binary-plist-v1", bytes: Data("bplist00broken".utf8)))
        try await expectFailure("malformed binary property list") { _ = try await probe.deliver(badBinary) }
        let kitchenCountBefore = await kitchen.applicationCount()
        let badCustom = Request(scope: kitchenRequest.scope, commandID: UUID(), operationID: kitchenRequest.operationID,
                                intentFingerprint: "fixture", command: Payload(typeID: kitchenRequest.command.typeID,
                                version: 1, codecID: "kitchen-lines-v1", bytes: Data("broken".utf8)))
        try await expectFailure("malformed custom payload", expected: .malformedPayload) { _ = try await probe.deliver(badCustom) }
        let kitchenCountAfter = await kitchen.applicationCount()
        try check(kitchenCountBefore == kitchenCountAfter, "malformed custom payload never reaches semantic application")
        let malformed = Request(scope: scope, commandID: UUID(), operationID: json.operationID,
                                intentFingerprint: "fixture", command: Payload(typeID: json.command.typeID,
                                version: 2, codecID: "json-v1", bytes: Data("not JSON".utf8)))
        try await expectFailure("malformed JSON") { _ = try await probe.deliver(malformed) }
        // Tamper with bytes while retaining their originally stored integrity value.
        let encoded = try JSONEncoder().encode(json)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        var payloadObject = object["command"] as! [String: Any]
        payloadObject["bytes"] = Data("tampered".utf8).base64EncodedString()
        object["command"] = payloadObject
        let corrupt = try JSONDecoder().decode(Request.self, from: JSONSerialization.data(withJSONObject: object))
        try await expectFailure("integrity mismatch", expected: .corruptBytes) { _ = try await probe.deliver(corrupt) }
        let missing = Request(scope: scope, commandID: UUID(), operationID: "unknown-operation",
                              intentFingerprint: "fixture", command: json.command)
        try await expectFailure("missing registration", expected: .unknownRegistration) { _ = try await probe.deliver(missing) }
        try await expectFailure("duplicate registration", expected: .duplicateRegistration) {
            try await probe.register("folio.replace-text", endpoint: host)
        }
        try check(host.applicationCount == applicationsBeforeFailures, "invalid inputs never reach semantic application")
        let rejected = try host.request(ReplaceText(unit: "missing", replacement: "Unused"))
        let result = try await probe.deliver(rejected)
        if case .rejected = result { print("PASS: host rejection remains application-neutral") }
        else { throw CheckFailure(description: "expected rejection") }
        let rejectionLookup = try await probe.lookup(rejected)
        if case .rejected = rejectionLookup { print("PASS: host rejection is available through outcome lookup") }
        else { throw CheckFailure(description: "rejection lost") }
        let unknownOutcome = try host.request(ReplaceText(unit: "chapter-1", replacement: "Not sent"))
        if case .unresolved = try await probe.lookup(unknownOutcome) { print("PASS: unknown outcome remains unresolved") }
        else { throw CheckFailure(description: "unknown outcome inferred") }

        let metadataCommand = try host.request(ReplaceText(unit: "chapter-1", replacement: "Metadata example"))
        let unknownMetadata = Payload(typeID: "future-preview", version: 99, codecID: "custom-future", bytes: Data([1, 2]))
        let metadataRequest = Request(scope: scope, commandID: metadataCommand.commandID,
                                      operationID: metadataCommand.operationID,
                                      intentFingerprint: metadataCommand.intentFingerprint,
                                      command: metadataCommand.command, metadata: unknownMetadata)
        _ = try accepted(await probe.deliver(metadataRequest))
        try check(host.text == "Metadata example", "uninterpretable display metadata does not prevent an otherwise valid operation")
        let old = Request(scope: scope, commandID: UUID(), operationID: json.operationID, intentFingerprint: "old-fixture",
                          command: Payload(typeID: json.command.typeID, version: 1, codecID: "json-v1",
                          bytes: try JSONCodec<OldReplaceText>().encode(OldReplaceText(unit: "chapter-1", content: "Legacy"))))
        let fixtures = ["json": SavedFixture(request: json, evidence: effect),
                        "xml": SavedFixture(request: xml, evidence: effect),
                        "binary": SavedFixture(request: binary, evidence: effect),
                        "custom": SavedFixture(request: kitchenRequest, evidence: kitchenEvidence),
                        "old": SavedFixture(request: old, evidence: effect)]
        for (name, saved) in fixtures {
            try JSONEncoder().encode(saved).write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
        }
        try check(fixtures.count == 5, "saved bounded fixture envelopes for a fresh reader process")
        print("WRITE PHASE COMPLETE")
    }
    @MainActor
    static func read(_ directory: URL) async throws {
        var records: [String: SavedFixture] = [:]
        var originals: [String: Data] = [:]
        for name in ["json", "xml", "binary", "custom", "old"] {
            let bytes = try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
            originals[name] = bytes
            records[name] = try JSONDecoder().decode(SavedFixture.self, from: bytes)
        }
        let json = records["json"]!, custom = records["custom"]!
        let host = WriteAdapter(scope: json.request.scope, resourceStore: json.evidence.resources[0].store)
        let kitchen = KitchenAdapter(scope: custom.request.scope)
        let probe = BoundaryProbe()
        try await probe.register("folio.replace-text", endpoint: host)
        try await probe.register("kitchen.organize", endpoint: kitchen)
        for name in ["json", "xml", "binary", "old"] {
            let saved = records[name]!
            try saved.request.command.validate()
            let decoded = try host.decode(saved.request.command)
            try check(decoded.replacement == (name == "old" ? "Legacy" : "After"), "fresh registration decodes \(name) fixture")
        }
        let destination = try await kitchen.inspect(custom.request.command)
        try check(destination == "Weekend", "fresh background registration decodes custom fixture")
        let effect = try JSONCodec<TextEffect>().decode(json.evidence.effect.bytes)
        try check(effect.before == "Before" && effect.after == "After", "fresh reader decodes accepted-effect fixture independently")
        let count = await kitchen.applicationCount()
        try check(host.applicationCount == 0 && count == 0 && host.text == "Before", "reading and registration rebuilding perform no semantic edits")
        for (name, original) in originals {
            try check(try Data(contentsOf: directory.appendingPathComponent("\(name).json")) == original,
                      "\(name) source bytes unchanged after version adaptation and inspection")
        }
        let data = try await probe.resolve(operationID: json.request.operationID, reference: json.evidence.resources[0])
        try check(data == Data("host-owned chapter asset".utf8), "fresh host resolves retained external resource identity")
        // A Codable conformance is not a guarantee that every value fits every format.
        try await expectFailure("JSON rejects non-finite floating-point default") { _ = try JSONCodec<Double>().encode(.infinity) }
        print("READ PHASE COMPLETE")
    }
}
