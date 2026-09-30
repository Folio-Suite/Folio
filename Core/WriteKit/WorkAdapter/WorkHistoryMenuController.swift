// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Reusable dynamic checkpoint menu for a Work host. Keep this controller alive while its menu is displayed.
/// The host supplies native saving and error presentation; UndoKit never owns those operations.
@MainActor public final class WorkHistoryMenuController: NSObject {
    private let history: WorkHistorySession
    private let save: @MainActor () async throws -> Void
    private let restored: @MainActor () -> Void
    private let willRestore: @MainActor () -> Void
    private let restoreFinished: @MainActor () -> Void
    private let reportError: @MainActor (Error) -> Void

    public init(history: WorkHistorySession, save: @escaping @MainActor () async throws -> Void,
                restored: @escaping @MainActor () -> Void, reportError: @escaping @MainActor (Error) -> Void,
                willRestore: @escaping @MainActor () -> Void = {},
                restoreFinished: @escaping @MainActor () -> Void = {}) {
        self.history = history
        self.save = save
        self.restored = restored
        self.willRestore = willRestore
        self.restoreFinished = restoreFinished
        self.reportError = reportError
    }

    /// Creates a bounded menu of saved checkpoint metadata. Opening it does not reconstruct historical content.
    public func menu() throws -> NSMenu {
        let menu = NSMenu(title: NSLocalizedString("work-history.menu", tableName: nil, bundle: WorkStore.bundle, value: "History", comment: "Title of the Work history menu."))
        let create = NSMenuItem(title: NSLocalizedString("work-history.create", tableName: nil, bundle: WorkStore.bundle, value: "Create Checkpoint…", comment: "Create a named Work checkpoint."),
                                action: #selector(createCheckpoint(_:)), keyEquivalent: "")
        create.target = self
        create.isEnabled = history.canSave
        menu.addItem(create)
        menu.addItem(.separator())
        for checkpoint in try history.checkpoints() {
            let title = checkpoint.name.isEmpty ? checkpoint.recordedAt.formatted() : checkpoint.name
            let item = NSMenuItem(title: title, action: #selector(restoreCheckpoint(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = checkpoint.id
            item.isEnabled = history.canSave
            menu.addItem(item)
        }
        menu.autoenablesItems = false
        return menu
    }

    @objc private func createCheckpoint(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("work-history.checkpoint-name", tableName: nil, bundle: WorkStore.bundle, value: "Name this checkpoint", comment: "Prompt for a Work checkpoint name.")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.setAccessibilityLabel(alert.messageText)
        alert.accessoryView = field
        alert.addButton(withTitle: NSLocalizedString("work-history.create-button", tableName: nil, bundle: WorkStore.bundle, value: "Create", comment: "Button confirming checkpoint creation."))
        alert.addButton(withTitle: NSLocalizedString("work-history.cancel", tableName: nil, bundle: WorkStore.bundle, value: "Cancel", comment: "Cancel checkpoint creation."))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue
        Task {
            do {
                _ = try await history.createCheckpoint(name: name)
                try await save()
            } catch { reportError(error) }
        }
    }

    @objc private func restoreCheckpoint(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        willRestore()
        Task {
            defer { restoreFinished() }
            do {
                try await history.restore(checkpointID: id)
                restored()
            } catch { reportError(error) }
        }
    }

}
