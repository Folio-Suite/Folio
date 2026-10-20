// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
import WriteKit

// MARK: - Document persistence and lifecycle

extension WriteDocument {
    /// Save a host-selected package without retained history. A successful
    /// replacement retires the live generation; a failed save leaves it intact.
    func saveOmittingHistory(to url: URL, ofType typeName: String,
                             completionHandler: @escaping (Error?) -> Void) {
        guard !documentSaveInProgress, let history = work.history else {
            completionHandler(WorkHistoryError.busy)
            return
        }
        Task { @MainActor in
            do {
                try await flushHistory()
                guard !documentSaveInProgress, nativeHistory?.canAttach ?? true else {
                    throw WorkHistoryError.busy
                }
                let publication = try history.beginOmissionPublication()
                let invocation = nativeHistory?.beginExternalOperation()
                if nativeHistory != nil && invocation == nil {
                    try history.cancelOmissionPublication(publication)
                    throw WorkHistoryError.busy
                }
                documentSaveInProgress = true
                omittingHistoryForCurrentSave = true
                super.save(to: url, ofType: typeName, for: .saveOperation) { [self] error in
                    omittingHistoryForCurrentSave = false
                    documentSaveInProgress = false
                    if let error {
                        do { try history.cancelOmissionPublication(publication) } catch {
                            reportHistoryError(error)
                        }
                        if let invocation {
                            nativeHistory?.finishInvocation(invocation, snapshot: historySnapshot(history))
                        }
                        completionHandler(error)
                        return
                    }
                    if let invocation {
                        nativeHistory?.finishInvocation(invocation, snapshot: historySnapshot(history))
                    }
                    do {
                        try history.completeOmissionAfterSave(publication)
                        try nativeHistory?.attach(snapshot: historySnapshot(history))
                        completionHandler(nil)
                    } catch {
                        if nativeHistory?.requiresReattachment == true {
                            try? nativeHistory?.attach(snapshot: historySnapshot(history))
                        }
                        completionHandler(WriteHistoryOmissionError.published(needsRecovery: error))
                    }
                }
            } catch { completionHandler(error) }
        }
    }

    /// Retry live reset or receipt cleanup after the package was already saved
    /// without history. A second call can also finish native reattachment.
    func retryPublishedHistoryOmission() throws {
        guard !documentSaveInProgress, let history = work.history else { throw WorkHistoryError.busy }
        if let publication = history.pendingOmissionPublication {
            try history.completeOmissionAfterSave(publication)
        }
        if let nativeHistory {
            guard nativeHistory.canAttach else { throw WorkHistoryError.busy }
            try nativeHistory.attach(snapshot: historySnapshot(history))
        }
    }

    // AppKit enters here for explicit saves and autosaves. Flush the asynchronous
    // host history before delegating the actual safe-save machinery to NSDocument.
    // Its completion handler, not the return from our write hook, reports publication.
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
                       completionHandler: @escaping (Error?) -> Void) {
        guard !documentSaveInProgress else {
            completionHandler(WorkHistoryError.busy)
            return
        }
        Task { @MainActor in
            do {
                let automaticSave = saveOperation == .autosaveElsewhereOperation ||
                    saveOperation == .autosaveInPlaceOperation || saveOperation == .autosaveAsOperation
                try await flushHistory(waitForNativeIdle: automaticSave)
                guard !documentSaveInProgress else { throw WorkHistoryError.busy }
                documentSaveInProgress = true
                super.save(to: url, ofType: typeName, for: saveOperation) { [self] error in
                    documentSaveInProgress = false
                    completionHandler(error)
                }
            } catch { completionHandler(error) }
        }
    }

    // Editing notifications restart this delay; they do not write files directly.
    // After native editing becomes idle, scheduleAutosaving asks AppKit to schedule
    // its normal document save path rather than introducing a second writer.
    func scheduleAutosavingAfterNativeIdle() {
        autosaveGeneration += 1
        let generation = autosaveGeneration
        autosaveIdleTask?.cancel()
        autosaveIdleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled, self.autosaveGeneration == generation else { return }
            self.autosaveIdleTask = nil
            self.scheduleAutosaving()
        }
    }

    func awaitNativeIdle() async {
        while let autosaveIdleTask { await autosaveIdleTask.value }
    }

    // AppKit’s close entry point is synchronous, but the durable history session has
    // asynchronous shutdown. Keep this document alive until it finishes, and call
    // super.close() only on success; a failure leaves the document available to retry.
    override func close() {
        guard let history = work.history else { super.close(); return }
        guard !closeInProgress else { return }
        closeInProgress = true
        autosaveIdleTask?.cancel()
        autosaveIdleTask = nil
        let closeInvocation = nativeHistory?.beginExternalOperation()
        let pending = submissionTail
        Task { @MainActor [self] in
            do {
                if let pending { await pending.value }
                try await history.close()
                finishClose()
            } catch {
                closeInProgress = false
                if let closeInvocation {
                    nativeHistory?.finishInvocation(closeInvocation, snapshot: historySnapshot(history))
                }
                reportHistoryError(error)
            }
        }
    }

    private func finishClose() { super.close() }

}

private enum WriteHistoryOmissionError: LocalizedError {
    case published(needsRecovery: Error)

    var errorDescription: String? {
        switch self {
        case .published:
            return NSLocalizedString(
                "write.history.omission-published", tableName: nil, bundle: .main,
                value: "The Work was saved without history. Resolve the open history session before another save.",
                comment: "History omission published, but live generation reset or receipt cleanup failed.")
        }
    }

    var underlyingError: Error {
        switch self {
        case .published(let cause): cause
        }
    }
}
