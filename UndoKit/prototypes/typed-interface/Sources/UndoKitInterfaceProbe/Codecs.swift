// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
import Foundation

// Value need not be Sendable. These helpers run synchronously on the host's actor.
public struct JSONCodec<Value: Codable> {
    public init() {}
    public func encode(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    public func decode(_ bytes: Data) throws -> Value {
        try JSONDecoder().decode(Value.self, from: bytes)
    }
}

public struct XMLPropertyListCodec<Value: Codable> {
    public init() {}
    public func encode(_ value: Value) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(value)
    }
    public func decode(_ bytes: Data) throws -> Value {
        try PropertyListDecoder().decode(Value.self, from: bytes)
    }
}

public struct BinaryPropertyListCodec<Value: Codable> {
    public init() {}
    public func encode(_ value: Value) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }
    public func decode(_ bytes: Data) throws -> Value {
        try PropertyListDecoder().decode(Value.self, from: bytes)
    }
}
