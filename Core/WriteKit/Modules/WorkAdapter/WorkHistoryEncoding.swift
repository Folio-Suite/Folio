// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

/// Work-owned codec identity and bytes, stored in a binary property-list envelope.
enum WorkHistoryEncoding {
  private struct Envelope: Codable {
    let codec: String
    let configuration: Data
    let bytes: Data
  }

  static func encode(_ bytes: Data, codec: String) throws -> Data {
    let envelope = Envelope(codec: codec, configuration: Data(), bytes: bytes)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try encoder.encode(envelope)
  }

  static func decodeBytes(from data: Data, codec: String) throws -> Data {
    let envelope = try PropertyListDecoder().decode(Envelope.self, from: data)
    guard envelope.codec == codec, envelope.configuration.isEmpty else {
      throw HistoryFailure(.compatibility, stage: .delivery, disposition: .usable)
    }
    return envelope.bytes
  }
}
