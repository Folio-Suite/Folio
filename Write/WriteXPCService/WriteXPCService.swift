// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Transport diagnostics only; domain operations belong to WriteKit.
@objc(WriteXPCServiceProtocol) protocol WriteXPCServiceProtocol {
    @objc(ping:reply:)
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void)
}

final class WriteXPCService: NSObject, WriteXPCServiceProtocol {
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void) {
        reply(nonce, ProcessInfo.processInfo.processIdentifier)
    }
}

final class WriteServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: WriteXPCServiceProtocol.self)
        connection.exportedObject = WriteXPCService()
        connection.resume()
        return true
    }
}
