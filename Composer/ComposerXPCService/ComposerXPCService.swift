// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Transport diagnostics only; domain operations belong to ComposerKit.
@objc(ComposerXPCServiceProtocol)
protocol ComposerXPCServiceProtocol {
    @objc(ping:reply:)
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void)
}

final class ComposerXPCService: NSObject, ComposerXPCServiceProtocol {
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void) {
        reply(nonce, ProcessInfo.processInfo.processIdentifier)
    }
}

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ComposerXPCServiceProtocol.self)
        connection.exportedObject = ComposerXPCService()
        connection.resume()
        return true
    }
}
