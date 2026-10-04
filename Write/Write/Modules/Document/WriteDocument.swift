// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit
import UndoKit
import WriteKit

@MainActor final class WriteDocument: NSDocument {
    private(set) var work = Work()
    private var nativeHistory: NativeHistoryRouter?
    private var historyMenu: WorkHistoryMenuController?
    private var submittedManuscript: Manuscript?
    private var countedManuscript: Manuscript?
    private var countedResources: [WorkResource]?
    private var submissionTail: Task<Void, Never>?
    private var submissionsPending = 0
    private var submissionError: Error?
    private var initialHistoryOpening = false
    private var initialHistoryInvocation: UUID?
    private var restorationInvocation: UUID?
    private var refreshingFromHistory = false
    private var closeInProgress = false
    private var autosaveIdleTask: Task<Void, Never>?
    private var autosaveGeneration = 0
    var omittingHistoryForCurrentSave = false
    private var documentSaveInProgress = false
    var historyErrorHandler: ((Error) -> Void)?

    private func reportHistoryError(_ error: Error) {
        if let historyErrorHandler { historyErrorHandler(error) } else { presentError(error) }
    }

    override init() {
        super.init()
        // Provisional NSTextView groups cannot drive NSDocument's automatic counts:
        // the Work host counts only authoritative accepted outcomes.
        hasUndoManager = false
    }

    override static var autosavesInPlace: Bool { true }

    override var isDocumentEdited: Bool {
        super.isDocumentEdited || submissionsPending > 0 ||
            (work.history.map { work.manuscript != $0.committedManuscript } ?? false)
    }

    override var hasUnautosavedChanges: Bool {
        super.hasUnautosavedChanges || submissionsPending > 0 ||
            (work.history.map { work.manuscript != $0.committedManuscript } ?? false)
    }

    override func makeWindowControllers() {
        let history: WorkHistorySession
        do { history = try work.enableHistory() } catch { presentError(error); return }
        let router = nativeHistory ?? NativeHistoryRouter()
        nativeHistory = router
        if submittedManuscript == nil { submittedManuscript = history.committedManuscript }
        if countedManuscript == nil { countedManuscript = history.committedManuscript }
        if countedResources == nil { countedResources = work.resources }
        configure(router: router, history: history)
        initialHistoryOpening = true
        initialHistoryInvocation = router.beginExternalOperation()
        let editor = ManuscriptViewController.make(work: work, undoManager: router.undoManager)
        editor.workDidChange = { [weak self] in
            self?.nativeHistory?.noteProvisionalEdit()
            self?.scheduleAutosavingAfterNativeIdle()
        }
        editor.nativeEditingDidSettle = { [weak self] in self?.settleProvisionalEdit() }
        editor.transientNativeEdit = { [weak self] in self?.nativeHistory?.noteTransientRegistration() }
        editor.historyRequested = { [weak self] in self?.showHistory(nil) }
        let controller = editor.makeWindowController()
        controller.window?.center()
        addWindowController(controller)
        editor.setSemanticEditingBlocked(router.isEditingBlocked)
        Task { @MainActor [weak self] in
            do {
                try await history.reconcile()
                self?.finishInitialHistoryOpen(history, router: router)
            } catch {
                self?.reportHistoryError(error)
                if let snapshot = self?.historySnapshot(history),
                   snapshot.scope != nil, snapshot.generation != nil,
                   let invocation = self?.initialHistoryInvocation {
                    router.finishInvocation(invocation, snapshot: snapshot)
                    self?.initialHistoryInvocation = nil
                    self?.initialHistoryOpening = false
                }
            }
        }
    }

}

// MARK: - Native history coordination

extension WriteDocument {
    private func configure(router: NativeHistoryRouter, history: WorkHistorySession) {
        history.didChange = { [weak self] in self?.publishHistoryAvailability() }
        router.settleEditing = { [weak self] in self?.settleNativeEditing() ?? false }
        router.undoRequested = { [weak self] in self?.performHistoryUndo(redo: false) }
        router.redoRequested = { [weak self] in self?.performHistoryUndo(redo: true) }
        router.barrierChanged = { [weak self] blocked in
            guard let self else { return }
            for controller in self.windowControllers {
                (controller.contentViewController as? ManuscriptViewController)?
                    .setSemanticEditingBlocked(blocked || self.closeInProgress)
            }
        }
        router.nativeGroupDidClose = { [weak self] _, count in
            guard let self, count > 0, self.nativeHistory?.hasRegistrationMismatch == true else { return }
            self.presentError(WorkHistoryError.busy)
        }
        publishHistoryAvailability()
    }

    private func finishInitialHistoryOpen(_ history: WorkHistorySession, router: NativeHistoryRouter) {
        guard initialHistoryOpening else { return }
        initialHistoryOpening = false
        if let invocation = initialHistoryInvocation {
            router.finishInvocation(invocation, snapshot: historySnapshot(history))
            initialHistoryInvocation = nil
        }
    }

    private func historySnapshot(_ history: WorkHistorySession) -> HistorySnapshot {
        history.availability
    }

    private func publishHistoryAvailability() {
        guard let history = work.history, let nativeHistory else { return }
        nativeHistory.update(snapshot: historySnapshot(history))
    }

    private func settleNativeEditing() -> Bool {
        for controller in windowControllers {
            guard let manuscript = controller.contentViewController as? ManuscriptViewController else { continue }
            if manuscript.hasMarkedText { return false }
        }
        for controller in windowControllers {
            (controller.contentViewController as? ManuscriptViewController)?.settleNativeEditing()
        }
        settleProvisionalEdit()
        return true
    }

    private func settleProvisionalEdit() {
        guard !refreshingFromHistory else { return }
        guard let history = work.history, let nativeHistory else { return }
        guard !windowControllers.contains(where: {
            ($0.contentViewController as? ManuscriptViewController)?.hasMarkedText == true
        }) else {
            return
        }
        let manuscript = work.manuscript
        guard manuscript != submittedManuscript else {
            nativeHistory.didSettleProvisionalEdit()
            return
        }
        submittedManuscript = manuscript
        nativeHistory.didQueueProvisionalEdit()
        submissionsPending += 1
        let previous = submissionTail
        submissionTail = Task { @MainActor [weak self] in
            if let previous { await previous.value }
            guard let self else { return }
            if self.submissionError == nil {
                do {
                    try await history.submit(manuscript: manuscript)
                } catch {
                    self.submissionError = error
                    self.reportHistoryError(error)
                }
            }
            self.accountCommittedChange(.changeDone)
            self.submissionsPending -= 1
            nativeHistory.didFinishQueuedEdit()
            self.publishHistoryAvailability()
        }
    }

    private func accountCommittedChange(_ kind: NSDocument.ChangeType) {
        guard let history = work.history else { return }
        let committed = history.committedManuscript
        guard countedManuscript != committed || countedResources != work.resources else { return }
        countedManuscript = committed
        countedResources = work.resources
        updateChangeCount(kind)
    }

    private func performHistoryUndo(redo: Bool) {
        guard let history = work.history, let nativeHistory else { return }
        guard let invocation = nativeHistory.pendingInvocationID else { return }
        let tail = submissionTail
        let origin = windowControllers.first(where: { $0.window === NSApp.keyWindow })?
            .contentViewController as? ManuscriptViewController
        let navigationRevision = origin?.navigationRevision
        let originWindow = origin?.view.window
        let originTextHadFocus = origin?.view.window?.firstResponder === origin?.activeEditor?.textView
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let tail { await tail.value }
            let before = history.committedManuscript
            if let submissionError = self.submissionError {
                self.reportHistoryError(submissionError)
            } else {
                do {
                    if redo { try await history.redo() } else { try await history.undo() }
                } catch { self.reportHistoryError(error) }
            }
            self.accountCommittedChange(redo ? .changeRedone : .changeUndone)
            self.submittedManuscript = history.committedManuscript
            let reveal = origin?.navigationRevision == navigationRevision && originWindow === NSApp.keyWindow
                ? self.singleChangedContentUnit(from: before, to: history.committedManuscript) : nil
            let restoreFocus = originTextHadFocus && originWindow?.firstResponder === origin?.activeEditor?.textView
            self.refreshCommittedEditors(reveal: reveal, in: origin, focus: restoreFocus)
            nativeHistory.finishInvocation(invocation, snapshot: self.historySnapshot(history),
                undoName: "", redoName: "")
        }
    }

    private func singleChangedContentUnit(from before: Manuscript, to after: Manuscript) -> FolioIdentifier? {
        let previous = Dictionary(uniqueKeysWithValues: before.units.map { ($0.identifier, $0) })
        let current = Dictionary(uniqueKeysWithValues: after.units.map { ($0.identifier, $0) })
        let changed = Set(previous.keys).union(current.keys).filter { previous[$0] != current[$0] }
        guard changed.count == 1, let identifier = changed.first, current[identifier] != nil else { return nil }
        return identifier
    }

    private func refreshCommittedEditors(reveal: FolioIdentifier? = nil,
                                         in origin: ManuscriptViewController? = nil, focus: Bool = false) {
        refreshingFromHistory = true
        defer { refreshingFromHistory = false }
        for controller in windowControllers {
            guard let manuscript = controller.contentViewController as? ManuscriptViewController else { continue }
            manuscript.refreshFromWork()
            if manuscript === origin, let reveal { manuscript.selectUnit(withIdentifier: reveal, focus: focus) }
        }
    }

    @IBAction func showHistory(_ sender: Any?) {
        guard let history = work.history, let window = windowControllers.first?.window,
              let contentView = window.contentView else { return }
        Task { @MainActor [self] in
            do {
                try await flushHistory()
                let menuController = WorkHistoryMenuController(history: history, save: { [weak self] in
                    guard let self, let url = self.fileURL else { throw WorkHistoryError.busy }
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        self.save(to: url, ofType: workDocumentType, for: .saveOperation) { error in
                            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                        }
                    }
                }, restored: { [weak self] in
                    self?.accountCommittedChange(.changeDone)
                    self?.submittedManuscript = history.committedManuscript
                    self?.refreshCommittedEditors()
                }, reportError: { [weak self] error in self?.reportHistoryError(error) },
                willRestore: { [weak self] in
                    guard let self, let invocation = self.nativeHistory?.beginExternalOperation() else {
                        throw WorkHistoryError.busy
                    }
                    self.restorationInvocation = invocation
                },
                restoreFinished: { [weak self] in
                    guard let self, let nativeHistory = self.nativeHistory else { return }
                    self.accountCommittedChange(.changeDone)
                    self.submittedManuscript = history.committedManuscript
                    self.refreshCommittedEditors()
                    if let invocation = self.restorationInvocation {
                        nativeHistory.finishInvocation(invocation, snapshot: self.historySnapshot(history),
                            undoName: "", redoName: "")
                        self.restorationInvocation = nil
                    }
                })
                historyMenu = menuController
                let menu = try menuController.menu()
                menu.popUp(positioning: nil, at: NSPoint(x: 20, y: contentView.bounds.height - 40), in: contentView)
            } catch { presentError(error) }
        }
    }

    /// Resource commands share native ordering, editing barriers and accepted change counts.
    func performResourceChange<Result>(
        _ operation: (WorkHistorySession) async throws -> Result
    ) async throws -> Result {
        guard !documentSaveInProgress, !closeInProgress else { throw WorkHistoryError.busy }
        let history = try work.enableHistory()
        if countedManuscript == nil { countedManuscript = history.committedManuscript }
        if countedResources == nil { countedResources = work.resources }
        try await flushHistory()
        let invocation = nativeHistory?.beginExternalOperation()
        if nativeHistory != nil && invocation == nil { throw WorkHistoryError.busy }
        defer {
            accountCommittedChange(.changeDone)
            if let invocation {
                nativeHistory?.finishInvocation(invocation, snapshot: historySnapshot(history))
            }
        }
        return try await operation(history)
    }

    /// Settle native text coalescing and wait for every earlier group before saving.
    func flushHistory(waitForNativeIdle: Bool = false) async throws {
        if waitForNativeIdle { await awaitNativeIdle() }
        guard let history = work.history else { return }
        if let submissionTail { await submissionTail.value }
        try await history.reconcile()
        if waitForNativeIdle { await awaitNativeIdle() }
        if let nativeHistory { finishInitialHistoryOpen(history, router: nativeHistory) }
        retryRejectedSubmission(history)
        guard settleNativeEditing() else { throw WorkHistoryError.busy }
        if let submissionTail { await submissionTail.value }
        if let submissionError { throw submissionError }
        guard history.canSave else { throw WorkHistoryError.busy }
    }

    private func retryRejectedSubmission(_ history: WorkHistorySession) {
        if submissionError != nil && !history.isSuspended {
            // An admission refusal or authoritative no-effect rejection leaves the
            // provisional editor content intact. Retry its current, possibly reduced,
            // value after reconciling the earlier request.
            accountCommittedChange(.changeDone)
            submissionError = nil
            submittedManuscript = history.committedManuscript
            if work.manuscript != history.committedManuscript { nativeHistory?.noteProvisionalEdit() }
        }
    }

}

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

    private func scheduleAutosavingAfterNativeIdle() {
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

    private func awaitNativeIdle() async {
        while let autosaveIdleTask { await autosaveIdleTask.value }
    }

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

    func adopt(_ opened: Work) throws {
        guard work.history == nil else { throw WorkHistoryError.busy }
        nativeHistory?.undoManager.removeAllActions()
        nativeHistory = nil
        submittedManuscript = nil
        countedManuscript = nil
        countedResources = nil
        submissionTail = nil
        submissionsPending = 0
        submissionError = nil
        work = opened
        for controller in windowControllers {
            (controller.contentViewController as? ManuscriptViewController)?.work = opened
        }
    }
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
