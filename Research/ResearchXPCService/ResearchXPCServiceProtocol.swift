// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

// Transport diagnostics only; domain operations belong to the owning Kit.
@objc(ResearchXPCServiceProtocol)
protocol ResearchXPCServiceProtocol {
    /// Echoes a caller nonce and returns the service PID to verify a live XPC exchange.
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void)
}
