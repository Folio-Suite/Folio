// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

// Transport adapter; domain behavior belongs to ResearchKit.
@objc(ResearchXPCService)
final class ResearchXPCService: NSObject, ResearchXPCServiceProtocol {
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void) {
        reply(nonce, Int32(ProcessInfo.processInfo.processIdentifier))
    }
}
