// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

// The embedded XPC service is a separate process with its own entry point.
// Foundation supplies the service listener; resuming it begins accepting connections.
// This transport shell currently exposes diagnostics, not Work/Library/Arrangement operations.
let delegate = WriteServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
// The embedded-service listener’s resume() hands control to Foundation and
// never returns; this entry point does not start a separate application run loop.
listener.resume()
