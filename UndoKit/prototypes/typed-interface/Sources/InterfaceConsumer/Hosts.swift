// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
// Illustrative domain types, not production Folio/KitchenMemory adapters.
import Foundation
import UndoKitInterfaceProbe

// Intentionally non-Sendable reference values: encode/decode only on the owning actor.
final class ReplaceText: Codable {
    let unit: String
    let replacement: String
    init(unit: String, replacement: String) { self.unit = unit; self.replacement = replacement }
}
struct OldReplaceText: Codable { let unit: String; let content: String }
struct TextEffect: Codable, Equatable { let unit: String; let before: String; let after: String }
struct Preview: Codable { let label: String }
final class TextModel { var text = "Before"; var applicationCount = 0 }

@MainActor
final class WriteAdapter: HostEndpoint {
    let scope: UUID
    let resourceStore: UUID
    private let model = TextModel()
    private var receipts: [UUID: Outcome] = [:]
    init(scope: UUID, resourceStore: UUID) { self.scope = scope; self.resourceStore = resourceStore }

    func request(_ command: ReplaceText, codecID: String = "json-v1", id: UUID = UUID()) throws -> Request {
        let bytes: Data
        switch codecID {
        case "json-v1": bytes = try JSONCodec<ReplaceText>().encode(command)
        case "xml-plist-v1": bytes = try XMLPropertyListCodec<ReplaceText>().encode(command)
        case "binary-plist-v1": bytes = try BinaryPropertyListCodec<ReplaceText>().encode(command)
        default: throw ProbeError.unsupportedCodec
        }
        // Host-defined intent representation, independent of selected storage codec.
        let intent = try JSONCodec<[String]>().encode([command.unit, command.replacement])
        return Request(scope: scope, commandID: id, operationID: "folio.replace-text",
                       intentFingerprint: Payload.digest(intent),
                       command: Payload(typeID: "folio.replace-text.command", version: 2, codecID: codecID, bytes: bytes),
                       metadata: Payload(typeID: "folio.preview", version: 1, codecID: "json-v1",
                                         bytes: try JSONCodec<Preview>().encode(Preview(label: "Edit chapter"))))
    }

    func decode(_ payload: Payload) throws -> ReplaceText {
        guard payload.typeID == "folio.replace-text.command" else { throw ProbeError.malformedPayload }
        switch (payload.version, payload.codecID) {
        case (1, "json-v1"):
            let old = try JSONCodec<OldReplaceText>().decode(payload.bytes)
            return ReplaceText(unit: old.unit, replacement: old.content)
        case (2, "json-v1"): return try JSONCodec<ReplaceText>().decode(payload.bytes)
        case (2, "xml-plist-v1"): return try XMLPropertyListCodec<ReplaceText>().decode(payload.bytes)
        case (2, "binary-plist-v1"): return try BinaryPropertyListCodec<ReplaceText>().decode(payload.bytes)
        case (1...2, _): throw ProbeError.unsupportedCodec
        default: throw ProbeError.unsupportedVersion
        }
    }

    func execute(_ request: Request) async throws -> Outcome {
        guard request.scope == scope else { return .rejected }
        let command = try decode(request.command) // Decode failure precedes semantic application.
        if command.unit != "chapter-1" {
            receipts[request.commandID] = .rejected
            return .rejected
        }
        let effect = TextEffect(unit: command.unit, before: model.text, after: command.replacement)
        let evidence = Evidence(effect: Payload(typeID: "folio.replace-text.effect", version: 1,
                                codecID: "json-v1", bytes: try JSONCodec<TextEffect>().encode(effect)),
                                resources: [ResourceReference(store: resourceStore, key: "chapter-asset")])
        // In-memory stand-in only; production must atomically persist effect + authoritative receipt.
        model.text = command.replacement
        model.applicationCount += 1
        receipts[request.commandID] = .accepted(evidence)
        return .accepted(evidence)
    }

    func lookup(scope: UUID, commandID: UUID) async -> Outcome {
        guard scope == self.scope else { return .unresolved }
        return receipts[commandID] ?? .unresolved
    }

    func compensate(_ payload: Payload, scope: UUID, commandID: UUID) async throws -> Outcome {
        guard scope == self.scope else { return .rejected }
        guard payload.typeID == "folio.replace-text.effect", payload.version == 1,
              payload.codecID == "json-v1" else { throw ProbeError.unsupportedVersion }
        let effect = try JSONCodec<TextEffect>().decode(payload.bytes)
        guard model.text == effect.after else { return .rejected }
        let compensation = TextEffect(unit: effect.unit, before: model.text, after: effect.before)
        let evidence = Evidence(effect: Payload(typeID: payload.typeID, version: 1, codecID: "json-v1",
                                bytes: try JSONCodec<TextEffect>().encode(compensation)))
        model.text = effect.before
        receipts[commandID] = .accepted(evidence)
        return .accepted(evidence)
    }

    func resolve(_ reference: ResourceReference) async throws -> Data {
        guard reference.store == resourceStore, reference.key == "chapter-asset" else {
            throw ProbeError.missingResource
        }
        return Data("host-owned chapter asset".utf8)
    }
    var text: String { model.text }
    var applicationCount: Int { model.applicationCount }
}

// This family remains one intact typed command; members are not registered individually.
final class OrganizeRecipes {
    let recipeIDs: [String]
    let destination: String
    init(recipeIDs: [String], destination: String) { self.recipeIDs = recipeIDs; self.destination = destination }
}
struct OrganizationEffect: Codable, Equatable {
    let before: [String: String]
    let after: [String: String]
}
final class OrganizationModel {
    var folders = ["recipe-1": "Inbox", "recipe-2": "Favorites"]
    var applicationCount = 0
}

// A deliberately different, versioned host codec: UTF-8 lines with an explicit grammar.
struct OrganizationCodec {
    func encode(_ value: OrganizeRecipes) throws -> Data {
        let fields = [value.destination] + value.recipeIDs
        guard fields.allSatisfy({ !$0.isEmpty && !$0.contains("\n") }) else { throw ProbeError.malformedPayload }
        return Data((["organization-v1"] + fields).joined(separator: "\n").utf8)
    }
    func decode(_ bytes: Data) throws -> OrganizeRecipes {
        guard let text = String(data: bytes, encoding: .utf8) else { throw ProbeError.malformedPayload }
        let fields = text.components(separatedBy: "\n")
        guard fields.count >= 3, fields[0] == "organization-v1",
              fields.dropFirst().allSatisfy({ !$0.isEmpty }) else { throw ProbeError.malformedPayload }
        return OrganizeRecipes(recipeIDs: Array(fields.dropFirst(2)), destination: fields[1])
    }
}

actor KitchenAdapter: HostEndpoint {
    let scope: UUID
    private let model = OrganizationModel()
    private var receipts: [UUID: Outcome] = [:]
    init(scope: UUID) { self.scope = scope }
    func request(recipeIDs: [String], destination: String) throws -> Request {
        let value = OrganizeRecipes(recipeIDs: recipeIDs, destination: destination)
        let bytes = try OrganizationCodec().encode(value)
        return Request(scope: scope, commandID: UUID(), operationID: "kitchen.organize",
                       intentFingerprint: Payload.digest(bytes),
                       command: Payload(typeID: "kitchen.organize.command", version: 1,
                                        codecID: "kitchen-lines-v1", bytes: bytes))
    }
    func execute(_ request: Request) async throws -> Outcome {
        guard request.scope == scope else { return .rejected }
        guard request.command.typeID == "kitchen.organize.command", request.command.version == 1 else {
            throw ProbeError.unsupportedVersion
        }
        guard request.command.codecID == "kitchen-lines-v1" else { throw ProbeError.unsupportedCodec }
        let value = try OrganizationCodec().decode(request.command.bytes)
        guard value.recipeIDs.allSatisfy({ model.folders[$0] != nil }) else {
            receipts[request.commandID] = .rejected
            return .rejected
        }
        let before = model.folders
        var after = before
        for id in value.recipeIDs { after[id] = value.destination }
        let evidence = Evidence(effect: Payload(typeID: "kitchen.organize.effect", version: 1,
                                codecID: "json-v1", bytes: try JSONCodec<OrganizationEffect>()
                                    .encode(OrganizationEffect(before: before, after: after))))
        model.folders = after
        model.applicationCount += 1
        receipts[request.commandID] = .accepted(evidence)
        return .accepted(evidence)
    }
    func lookup(scope: UUID, commandID: UUID) async -> Outcome {
        guard scope == self.scope else { return .unresolved }
        return receipts[commandID] ?? .unresolved
    }
    func compensate(_ payload: Payload, scope: UUID, commandID: UUID) async throws -> Outcome {
        guard scope == self.scope else { return .rejected }
        guard payload.typeID == "kitchen.organize.effect", payload.version == 1,
              payload.codecID == "json-v1" else { throw ProbeError.unsupportedVersion }
        let effect = try JSONCodec<OrganizationEffect>().decode(payload.bytes)
        guard model.folders == effect.after else { return .rejected }
        let evidence = Evidence(effect: Payload(typeID: payload.typeID, version: 1, codecID: "json-v1",
                                bytes: try JSONCodec<OrganizationEffect>()
                                    .encode(OrganizationEffect(before: model.folders, after: effect.before))))
        model.folders = effect.before
        receipts[commandID] = .accepted(evidence)
        return .accepted(evidence)
    }
    func resolve(_ reference: ResourceReference) async throws -> Data { throw ProbeError.missingResource }
    func state() -> [String: String] { model.folders }
    func applicationCount() -> Int { model.applicationCount }
    func inspect(_ payload: Payload) throws -> String {
        try OrganizationCodec().decode(payload.bytes).destination
    }
}
