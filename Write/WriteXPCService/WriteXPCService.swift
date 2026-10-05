// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

/// Transport diagnostics only; domain operations belong to WriteKit.
@objc(WriteXPCServiceProtocol) protocol WriteXPCServiceProtocol {
    /// Echoes a nonce and the service process identifier to test transport liveness.
    /// This diagnostic does not load a document or establish domain-host authority.
    @objc(ping:reply:)
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void)
}

final class WriteXPCService: NSObject, WriteXPCServiceProtocol {
    func ping(_ nonce: String, reply: @escaping (String, Int32) -> Void) {
        reply(nonce, ProcessInfo.processInfo.processIdentifier)
    }
}

final class WriteServiceDelegate: NSObject, NSXPCListenerDelegate {
    // Foundation invokes this for each incoming connection. Configure the exported
    // protocol and per-connection object before resuming message delivery.
    // See NSXPCListenerDelegate.listener(_:shouldAcceptNewConnection:) in Foundation.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: WriteXPCServiceProtocol.self)
        connection.exportedObject = WriteXPCService()
        connection.resume()
        return true
    }
}
