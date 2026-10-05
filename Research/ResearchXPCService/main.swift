// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    // Configure each incoming connection before enabling its message delivery.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ResearchXPCServiceProtocol.self)
        connection.exportedObject = ResearchXPCService()
        connection.resume()
        return true
    }
}

enum ResearchServiceMain {
    static func main() {
        // The embedded XPC service is a separate process with its own entry point.
        // Foundation supplies the service listener; resuming it begins accepting connections.
        // This transport shell currently exposes diagnostics, not Work/Library/Arrangement operations.
        let delegate = ServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        // The embedded-service listener’s resume() hands control to Foundation and
        // never returns; this entry point does not start a separate application run loop.
        listener.resume()
    }
}

ResearchServiceMain.main()
