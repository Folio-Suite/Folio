// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
// This must FAIL Swift 6 complete concurrency checking.
final class MutableDomainObject { var text = "host-owned" }
actor Receiver { func consume(_ object: MutableDomainObject) { object.text = "changed" } }
@MainActor
func invalidCrossing(_ object: MutableDomainObject, receiver: Receiver) async {
    await receiver.consume(object)
    print(object.text)
}
