// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
// DISPOSABLE INTERFACE PROBE: no history store, queue, durability or recovery engine.
import Foundation
import CryptoKit

public enum ProbeError: Error, Equatable, Sendable {
    case tooLarge, corruptBytes, unknownRegistration, duplicateRegistration
    case unsupportedVersion, unsupportedCodec, missingResource, malformedPayload
}

public struct ResourceReference: Codable, Sendable, Equatable {
    public let store: UUID
    public let key: String
    public init(store: UUID, key: String) { self.store = store; self.key = key }
}

public struct Payload: Codable, Sendable, Equatable {
    public let typeID: String
    public let version: Int
    public let codecID: String
    public let bytes: Data
    public let integrity: String
    public init(typeID: String, version: Int, codecID: String, bytes: Data) {
        self.typeID = typeID; self.version = version; self.codecID = codecID
        self.bytes = bytes; self.integrity = Self.digest(bytes)
    }
    public static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    // Fixture limit only. U6, not this experiment, selects production ceilings.
    public func validate(maxBytes: Int = 4096) throws {
        guard bytes.count <= maxBytes else { throw ProbeError.tooLarge }
        guard integrity == Self.digest(bytes) else { throw ProbeError.corruptBytes }
    }
}

public struct Request: Codable, Sendable, Equatable {
    public let scope: UUID
    public let commandID: UUID
    public let operationID: String
    public let intentFingerprint: String
    public let command: Payload
    public let metadata: Payload?
    public init(scope: UUID, commandID: UUID, operationID: String,
                intentFingerprint: String, command: Payload, metadata: Payload? = nil) {
        self.scope = scope; self.commandID = commandID; self.operationID = operationID
        self.intentFingerprint = intentFingerprint; self.command = command; self.metadata = metadata
    }
}

public struct Evidence: Codable, Sendable, Equatable {
    public let effect: Payload
    public let resources: [ResourceReference]
    public init(effect: Payload, resources: [ResourceReference] = []) {
        self.effect = effect; self.resources = resources
    }
}

public enum Outcome: Sendable {
    case accepted(Evidence)
    case rejected
    case unresolved
}

// Hosts own implementation isolation. Only Sendable messages cross this interface.
public protocol HostEndpoint: Sendable {
    func execute(_ request: Request) async throws -> Outcome
    func lookup(scope: UUID, commandID: UUID) async -> Outcome
    func compensate(_ effect: Payload, scope: UUID, commandID: UUID) async throws -> Outcome
    func resolve(_ reference: ResourceReference) async throws -> Data
}

public actor BoundaryProbe {
    private var endpoints: [String: any HostEndpoint] = [:]
    public init() {}
    public func register(_ operationID: String, endpoint: any HostEndpoint) throws {
        guard endpoints[operationID] == nil else { throw ProbeError.duplicateRegistration }
        endpoints[operationID] = endpoint
    }
    private func endpoint(_ operationID: String) throws -> any HostEndpoint {
        guard let endpoint = endpoints[operationID] else { throw ProbeError.unknownRegistration }
        return endpoint
    }
    public func deliver(_ request: Request) async throws -> Outcome {
        try request.command.validate()
        try request.metadata?.validate()
        // Deliberately just transport: not admission, preparation, FIFO, or finalization.
        return try await endpoint(request.operationID).execute(request)
    }
    public func lookup(_ request: Request) async throws -> Outcome {
        await (try endpoint(request.operationID)).lookup(scope: request.scope, commandID: request.commandID)
    }
    public func compensate(operationID: String, effect: Payload, scope: UUID, commandID: UUID) async throws -> Outcome {
        try effect.validate()
        return try await endpoint(operationID).compensate(effect, scope: scope, commandID: commandID)
    }
    public func resolve(operationID: String, reference: ResourceReference) async throws -> Data {
        try await endpoint(operationID).resolve(reference)
    }
    public func frameworkFixture() throws -> Data {
        guard let url = Bundle.module.url(forResource: "interface-fixture", withExtension: "json") else {
            throw ProbeError.missingResource
        }
        return try Data(contentsOf: url)
    }
}
