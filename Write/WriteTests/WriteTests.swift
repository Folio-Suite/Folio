// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import CoreData
import UniformTypeIdentifiers
import WriteKit
import XCTest
@testable import Write

@MainActor final class WriteTests: XCTestCase {
    func testDocumentRegistrationUsesWriteDocument() {
        XCTAssertTrue(NSDocumentController.shared.documentClass(forType: workDocumentType) === WriteDocument.self)
    }

    func testAppMenusUseWriteKitSemanticImages() throws {
        let delegate = try XCTUnwrap(NSApplication.shared.delegate as? AppDelegate)
        let emphasis = try XCTUnwrap(delegate.emphasisMenuItem)
        let strong = try XCTUnwrap(delegate.strongEmphasisMenuItem)
        XCTAssertNotNil(emphasis.image)
        XCTAssertNotNil(strong.image)
    }

    private func titleField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.identifier?.rawValue == "contentUnitTitle" { return field }
        for child in view.subviews {
            if let field = titleField(in: child) { return field }
        }
        return nil
    }

    private func save(_ document: WriteDocument, to url: URL,
                      for operation: NSDocument.SaveOperationType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.save(to: url, ofType: workDocumentType, for: operation) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func insert(_ string: String, in document: WriteDocument) async throws {
        if document.windowControllers.isEmpty { document.makeWindowControllers() }
        try await document.flushHistory()
        let manuscript = try XCTUnwrap(document.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let editor = try XCTUnwrap(manuscript.activeEditor)
        _ = editor.view
        editor.textView.insertText(string, replacementRange: NSRange(location: editor.textView.string.count, length: 0))
    }

    func testDocumentWritesAndReopensNativePackage() async throws {
        let document = WriteDocument()
        document.makeWindowControllers()
        try await document.flushHistory()
        defer { document.close() }
        let manuscript = try XCTUnwrap(document.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let editor = try XCTUnwrap(manuscript.activeEditor)
        _ = editor.view
        editor.textView.insertText("A beginning.\nAnother paragraph.", replacementRange: NSRange(location: 0, length: 0))
        editor.textView.setSelectedRange(NSRange(location: 2, length: 9))
        editor.toggleBold(nil)
        manuscript.addContentUnit(nil)
        try XCTUnwrap(titleField(in: manuscript.view)).stringValue = "Next Chapter"
        manuscript.renameContentUnit(nil)
        manuscript.activeEditor.textView.insertText("Independent second unit.",
            replacementRange: NSRange(location: 0, length: 0))
        let secondIdentifier = try XCTUnwrap(manuscript.selectedUnitIdentifier)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }

        try await document.flushHistory()
        try document.write(to: url, ofType: workDocumentType)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathComponent("Work.sqlite").path))
        let detectedType = try NSDocumentController.shared.typeForContents(of: url)
        let type = try XCTUnwrap(UTType(detectedType))
        XCTAssertEqual(type, UTType(workDocumentType))
        XCTAssertTrue(type.conforms(to: .package))
        XCTAssertTrue(type.conforms(to: .content))

        let loaded = try WriteDocument(contentsOf: url, ofType: detectedType)
        loaded.makeWindowControllers()
        try await loaded.flushHistory()
        defer { loaded.close() }
        let loadedManuscript = try XCTUnwrap(loaded.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let reopened = try XCTUnwrap(loadedManuscript.activeEditor)
        _ = reopened.view
        XCTAssertEqual(reopened.textView.string, editor.textView.string)
        let font = try XCTUnwrap(reopened.textView.textStorage?.attribute(.font, at: 3, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        loadedManuscript.selectUnit(withIdentifier: secondIdentifier)
        XCTAssertEqual(loadedManuscript.activeEditor.textView.string, "Independent second unit.")
        XCTAssertEqual(loadedManuscript.work.text(withIdentifier: secondIdentifier)?.title, "Next Chapter")
    }

    func testNativeSafeSaveKeepsStoreIdentityAfterAnEdit() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }

        let initial = WriteDocument()
        try initial.write(to: url, ofType: workDocumentType)
        initial.close()
        let storeURL = url.appendingPathComponent("Work.sqlite")
        let originalMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL)
        let originalStoreIdentifier = try XCTUnwrap(originalMetadata[NSStoreUUIDKey] as? String)

        let document = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        document.makeWindowControllers()
        try await document.flushHistory()
        defer { document.close() }
        let manuscript = try XCTUnwrap(document.windowControllers.first?.contentViewController as? ManuscriptViewController)
        let editor = try XCTUnwrap(manuscript.activeEditor)
        _ = editor.view
        editor.textView.insertText("Saved through AppKit.", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(document.isDocumentEdited)

        try await document.flushHistory()
        try document.writeSafely(to: url, ofType: workDocumentType, for: .saveOperation)

        let savedMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL)
        XCTAssertEqual(savedMetadata[NSStoreUUIDKey] as? String, originalStoreIdentifier)
        let reopened = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        defer { reopened.close() }
        XCTAssertEqual(reopened.work.text.string, "Saved through AppKit.")
    }

    func testSaveAsAndSaveToLeaveIndependentPackages() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalURL = directory.appendingPathComponent("Original.flwrbundle")
        let saveAsURL = directory.appendingPathComponent("Saved As.flwrbundle")
        let saveToURL = directory.appendingPathComponent("Copy.flwrbundle")

        let initial = WriteDocument()
        try initial.write(to: originalURL, ofType: workDocumentType)
        initial.close()

        let document = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { document.close() }
        try await insert("First edit.", in: document)
        try await save(document, to: saveAsURL, for: .saveAsOperation)
        XCTAssertEqual(document.fileURL, saveAsURL)

        let original = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { original.close() }
        XCTAssertEqual(original.work.text.string, "")
        let savedAs = try WriteDocument(contentsOf: saveAsURL, ofType: workDocumentType)
        defer { savedAs.close() }
        XCTAssertEqual(savedAs.work.text.string, "First edit.")

        try await insert(" Second edit.", in: document)
        try await save(document, to: saveToURL, for: .saveToOperation)
        XCTAssertEqual(document.fileURL, saveAsURL)
        let copied = try WriteDocument(contentsOf: saveToURL, ofType: workDocumentType)
        defer { copied.close() }
        XCTAssertEqual(copied.work.text.string, "First edit. Second edit.")
        let unchangedSavedAs = try WriteDocument(contentsOf: saveAsURL, ofType: workDocumentType)
        defer { unchangedSavedAs.close() }
        XCTAssertEqual(unchangedSavedAs.work.text.string, "First edit.")
    }

    func testAutosaveInPlaceClearsEditedStateAndReopens() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("flwrbundle")
        defer { try? FileManager.default.removeItem(at: url) }
        let initial = WriteDocument()
        try initial.write(to: url, ofType: workDocumentType)
        initial.close()

        let document = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        defer { document.close() }
        try await insert("Autosaved edit.", in: document)
        XCTAssertTrue(document.isDocumentEdited)
        try await save(document, to: url, for: .autosaveInPlaceOperation)
        XCTAssertFalse(document.isDocumentEdited)
        let reopened = try WriteDocument(contentsOf: url, ofType: workDocumentType)
        defer { reopened.close() }
        XCTAssertEqual(reopened.work.text.string, "Autosaved edit.")
    }

    func testFailedSaveToKeepsOriginalAndEditedWorkForRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalURL = directory.appendingPathComponent("Original.flwrbundle")
        let unavailableURL = directory.appendingPathComponent("Missing Parent")
            .appendingPathComponent("Failed.flwrbundle")
        let retryURL = directory.appendingPathComponent("Retry.flwrbundle")

        let initial = WriteDocument()
        try initial.write(to: originalURL, ofType: workDocumentType)
        initial.close()
        let originalBytes = try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite"))

        let document = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { document.close() }
        try await insert("Still editable.", in: document)
        do {
            try await save(document, to: unavailableURL, for: .saveToOperation)
            XCTFail("Saving into a missing parent directory should fail")
        } catch {
            XCTAssertEqual(try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite")), originalBytes)
            XCTAssertEqual(document.work.text.string, "Still editable.")
            XCTAssertTrue(document.isDocumentEdited)
        }

        try await save(document, to: retryURL, for: .saveToOperation)
        let retried = try WriteDocument(contentsOf: retryURL, ofType: workDocumentType)
        defer { retried.close() }
        XCTAssertEqual(retried.work.text.string, "Still editable.")
    }

    func testUpgradedResourceSurvivesNativeSaveAutosaveAndIndependentCopy() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalURL = directory.appendingPathComponent("Original.flwrbundle")
        let copyURL = directory.appendingPathComponent("Copy.flwrbundle")
        let unavailableURL = directory.appendingPathComponent("Missing Parent")
            .appendingPathComponent("Failed.flwrbundle")
        let resourceURL = directory.appendingPathComponent("Large Reference.bin")
        let resourceBytes = Data(repeating: 0xA5, count: 1_000_000)
        try resourceBytes.write(to: resourceURL)

        let initial = WriteDocument()
        try initial.write(to: originalURL, ofType: workDocumentType)
        initial.close()
        let originalStoreBytes = try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite"))

        let document = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { document.close() }
        try document.upgradeStorage()
        let resourceIdentifier = try document.importResource(from: resourceURL)
        try await insert("First text.", in: document)

        do {
            try await save(document, to: unavailableURL, for: .saveToOperation)
            XCTFail("Saving into a missing parent directory should fail")
        } catch {
            XCTAssertEqual(try Data(contentsOf: originalURL.appendingPathComponent("Work.sqlite")), originalStoreBytes)
            let oldPackage = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
            defer { oldPackage.close() }
            XCTAssertEqual(oldPackage.work.storageVersion, .v1)
        }

        try await save(document, to: originalURL, for: .saveOperation)
        XCTAssertEqual(document.fileURL, originalURL)
        let reopened = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { reopened.close() }
        XCTAssertEqual(reopened.work.storageVersion, .v2)
        XCTAssertEqual(reopened.work.text.string, "First text.")
        let reopenedExport = directory.appendingPathComponent("Reopened Export.bin")
        try reopened.work.exportResource(withIdentifier: resourceIdentifier, to: reopenedExport)
        XCTAssertEqual(try Data(contentsOf: reopenedExport), resourceBytes)

        try await save(document, to: copyURL, for: .saveToOperation)
        try await insert(" Second text.", in: document)
        try await save(document, to: originalURL, for: .autosaveInPlaceOperation)

        let copied = try WriteDocument(contentsOf: copyURL, ofType: workDocumentType)
        defer { copied.close() }
        XCTAssertEqual(copied.work.text.string, "First text.")
        XCTAssertEqual(copied.work.storageVersion, .v2)
        let copiedExport = directory.appendingPathComponent("Copied Export.bin")
        try copied.work.exportResource(withIdentifier: resourceIdentifier, to: copiedExport)
        XCTAssertEqual(try Data(contentsOf: copiedExport), resourceBytes)

        let autosaved = try WriteDocument(contentsOf: originalURL, ofType: workDocumentType)
        defer { autosaved.close() }
        XCTAssertEqual(autosaved.work.text.string, "First text. Second text.")
        let autosavedExport = directory.appendingPathComponent("Autosaved Export.bin")
        try autosaved.work.exportResource(withIdentifier: resourceIdentifier, to: autosavedExport)
        XCTAssertEqual(try Data(contentsOf: autosavedExport), resourceBytes)
    }

    func testResourceOnlyMutationsMarkDocumentEditedAndAutosave() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let packageURL = directory.appendingPathComponent("Work.flwrbundle")
        let resourceURL = directory.appendingPathComponent("Reference.bin")
        let resourceBytes = Data(repeating: 0x73, count: 4_096)
        try resourceBytes.write(to: resourceURL)

        let initial = WriteDocument()
        try initial.write(to: packageURL, ofType: workDocumentType)
        initial.close()
        let document = try WriteDocument(contentsOf: packageURL, ofType: workDocumentType)
        defer { document.close() }
        XCTAssertFalse(document.isDocumentEdited)

        try document.upgradeStorage()
        XCTAssertTrue(document.isDocumentEdited)
        let resourceIdentifier = try document.importResource(from: resourceURL)
        try await save(document, to: packageURL, for: .autosaveInPlaceOperation)
        XCTAssertFalse(document.isDocumentEdited)
        let reopened = try WriteDocument(contentsOf: packageURL, ofType: workDocumentType)
        defer { reopened.close() }
        XCTAssertEqual(reopened.work.storageVersion, .v2)
        XCTAssertEqual(reopened.work.resources.map(\.identifier), [resourceIdentifier])
        let exportedURL = directory.appendingPathComponent("Exported.bin")
        try reopened.work.exportResource(withIdentifier: resourceIdentifier, to: exportedURL)
        XCTAssertEqual(try Data(contentsOf: exportedURL), resourceBytes)

        try document.removeResource(withIdentifier: resourceIdentifier)
        XCTAssertTrue(document.isDocumentEdited)
        try await save(document, to: packageURL, for: .autosaveInPlaceOperation)
        XCTAssertFalse(document.isDocumentEdited)
        let afterRemoval = try WriteDocument(contentsOf: packageURL, ofType: workDocumentType)
        defer { afterRemoval.close() }
        XCTAssertEqual(afterRemoval.work.storageVersion, .v2)
        XCTAssertTrue(afterRemoval.work.resources.isEmpty)
        XCTAssertEqual(afterRemoval.work.text.string, "")
    }

    func testFailedResourceMutationsAndSavePreserveDirtyState() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let packageURL = directory.appendingPathComponent("Work.flwrbundle")
        let resourceURL = directory.appendingPathComponent("Reference.bin")
        try Data([0x52, 0x46]).write(to: resourceURL)
        let invalidURL = directory.appendingPathComponent("Missing.bin")
        let unavailableURL = directory.appendingPathComponent("Missing Parent")
            .appendingPathComponent("Failed.flwrbundle")

        let initial = WriteDocument()
        try initial.write(to: packageURL, ofType: workDocumentType)
        initial.close()
        let document = try WriteDocument(contentsOf: packageURL, ofType: workDocumentType)
        defer { document.close() }
        XCTAssertFalse(document.isDocumentEdited)
        XCTAssertThrowsError(try document.importResource(from: resourceURL))
        XCTAssertFalse(document.isDocumentEdited)

        try document.upgradeStorage()
        try await save(document, to: packageURL, for: .saveOperation)
        XCTAssertFalse(document.isDocumentEdited)
        try document.upgradeStorage()
        XCTAssertFalse(document.isDocumentEdited)
        XCTAssertThrowsError(try document.importResource(from: invalidURL))
        XCTAssertThrowsError(try document.removeResource(withIdentifier: document.work.identifier))
        XCTAssertFalse(document.isDocumentEdited)

        let resourceIdentifier = try document.importResource(from: resourceURL)
        XCTAssertTrue(document.isDocumentEdited)
        do {
            try await save(document, to: unavailableURL, for: .saveToOperation)
            XCTFail("Saving into a missing parent directory should fail")
        } catch {
            XCTAssertTrue(document.isDocumentEdited)
            XCTAssertEqual(document.work.resources.map(\.identifier), [resourceIdentifier])
        }
        try await save(document, to: packageURL, for: .autosaveInPlaceOperation)
        XCTAssertFalse(document.isDocumentEdited)
        let reopened = try WriteDocument(contentsOf: packageURL, ofType: workDocumentType)
        defer { reopened.close() }
        XCTAssertEqual(reopened.work.resources.map(\.identifier), [resourceIdentifier])
    }
}
