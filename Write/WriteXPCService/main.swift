// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import Foundation

let delegate = WriteServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
