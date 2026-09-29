// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ResearchXPCServiceProtocol.self)
        connection.exportedObject = ResearchXPCService()
        connection.resume()
        return true
    }
}

enum ResearchServiceMain {
    static func main() {
        let delegate = ServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
    }
}

ResearchServiceMain.main()
