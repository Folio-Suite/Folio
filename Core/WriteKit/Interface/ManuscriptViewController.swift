// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

/// Storyboard Manuscript sidebar with retained editors for one Work's Content Units.
@MainActor
public final class ManuscriptViewController: NSViewController,
  NSTableViewDataSource, NSTableViewDelegate {
  public var work: Work! {
    didSet {
      activeEditor?.view.removeFromSuperview()
      for controller in children { controller.removeFromParent() }
      editors.removeAll()
      activeEditor = nil
      selectedUnitIdentifier = nil
      if isViewLoaded { selectUnit(withIdentifier: work.text.identifier) }
    }
  }
  public private(set) var activeEditor: EditorViewController!
  public private(set) var selectedUnitIdentifier: FolioIdentifier?
  public private(set) var navigationRevision = 0
  public var workDidChange: (() -> Void)?
  public var transientNativeEdit: (() -> Void)?
  public var nativeEditingDidSettle: (() -> Void)?
  public var historyRequested: (() -> Void)?

  @IBOutlet private var unitTable: NSTableView!
  @IBOutlet var unitTitle: NSTextField!
  @IBOutlet private var editorHost: NSView!
  @IBOutlet private var addButton: NSButton!
  @IBOutlet private var moveUpButton: NSButton!
  @IBOutlet private var moveDownButton: NSButton!

  private var documentUndoManager: UndoManager!
  private var editors: [FolioIdentifier: EditorViewController] = [:]
  private weak var documentWindowController: NSWindowController?
  private var updatingSelection = false
  private var semanticEditingBlocked = false

  public static func make(work: Work, undoManager: UndoManager) -> ManuscriptViewController {
    guard
      let controller = NSStoryboard(name: "Editor", bundle: writeKitBundle)
        .instantiateController(withIdentifier: "Manuscript") as? ManuscriptViewController
    else {
      preconditionFailure("Missing Manuscript storyboard controller")
    }
    controller.work = work
    controller.documentUndoManager = undoManager
    return controller
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    addButton.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.add-content-unit", tableName: nil, bundle: writeKitBundle,
        value: "Add Content Unit",
        comment: "Accessibility label for adding a Content Unit to the Manuscript."
      ))
    moveUpButton.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.move-content-unit-up", tableName: nil, bundle: writeKitBundle,
        value: "Move Content Unit Up",
        comment: "Accessibility label: move the selected Content Unit earlier in the Manuscript."))
    moveDownButton.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.move-content-unit-down", tableName: nil, bundle: writeKitBundle,
        value: "Move Content Unit Down",
        comment: "Accessibility label: move the selected Content Unit later in the Manuscript."))
    unitTable.dataSource = self
    unitTable.delegate = self
    unitTable.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.units.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Manuscript units",
        comment: "Accessibility name of the table listing Content Units in reading order."))
    unitTable.identifier = NSUserInterfaceItemIdentifier("manuscriptUnits")
    unitTitle.setAccessibilityLabel(
      NSLocalizedString(
        "content-unit.title.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Content Unit title",
        comment: "Accessibility name of the editable title field."))
    unitTitle.identifier = NSUserInterfaceItemIdentifier("contentUnitTitle")
    selectUnit(withIdentifier: work.text.identifier)
  }

  public func makeWindowController() -> NSWindowController {
    _ = view
    guard
      let window = NSStoryboard(name: "Editor", bundle: writeKitBundle)
        .instantiateController(withIdentifier: "EditorWindow") as? NSWindowController
    else {
      preconditionFailure("Missing Editor Window storyboard controller")
    }
    documentWindowController = window
    window.contentViewController = self
    if let selectedUnitIdentifier { selectUnit(withIdentifier: selectedUnitIdentifier) }
    return window
  }

  public func numberOfRows(in tableView: NSTableView) -> Int { work.manuscript.units.count }

  public func tableView(
    _ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?,
    row: Int
  ) -> Any? {
    work.manuscript.units[row].title
  }

  public func tableViewSelectionDidChange(_ notification: Notification) {
    guard !updatingSelection, unitTable.selectedRow >= 0 else { return }
    selectUnit(withIdentifier: work.manuscript.units[unitTable.selectedRow].identifier)
  }

  public func selectUnit(withIdentifier identifier: FolioIdentifier, focus: Bool = true) {
    guard let unit = work.text(withIdentifier: identifier) else { return }
    _ = view
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
    if selectedUnitIdentifier != identifier { navigationRevision += 1 }
    activeEditor?.view.removeFromSuperview()
    let editor: EditorViewController
    if let existing = editors[identifier] {
      editor = existing
    } else {
      editor = EditorViewController.make(
        work: work, contentUnitIdentifier: identifier,
        undoManager: documentUndoManager)
      editors[identifier] = editor
      addChild(editor)
      editor.textDidChange = { [weak self] in
        guard let self else { return }
        if self.selectedUnitIdentifier != identifier { self.selectUnit(withIdentifier: identifier) }
        self.workDidChange?()
      }
      editor.undoDidChangeText = { [weak self] in self?.selectUnit(withIdentifier: identifier) }
      editor.transientNativeEdit = { [weak self] in self?.transientNativeEdit?() }
      editor.nativeEditingDidSettle = { [weak self] in self?.nativeEditingDidSettle?() }
      editor.historyRequested = { [weak self] in self?.historyRequested?() }
      editor.setSemanticEditingBlocked(semanticEditingBlocked)
    }
    activeEditor = editor
    selectedUnitIdentifier = identifier
    editor.view.frame = editorHost.bounds
    editor.view.autoresizingMask = [.width, .height]
    editorHost.addSubview(editor.view)
    if let documentWindowController { editor.connectToolbar(documentWindowController) }
    updatingSelection = true
    unitTable.reloadData()
    let index = work.manuscript.units.firstIndex(where: { $0.identifier == unit.identifier })!
    unitTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    unitTable.scrollRowToVisible(index)
    unitTitle.stringValue = unit.title
    moveUpButton.isEnabled = !semanticEditingBlocked && index > 0
    moveDownButton.isEnabled = !semanticEditingBlocked && index + 1 < work.manuscript.units.count
    updatingSelection = false
    if focus { view.window?.makeFirstResponder(editor.textView) }
  }

  /// Apply a finalized Work state to attached editors without registering another edit.
  public func refreshFromWork() {
    guard isViewLoaded else { return }
    for (identifier, editor) in editors where work.text(withIdentifier: identifier) != nil {
      editor.refreshFromWork()
    }
    if let selectedUnitIdentifier, work.text(withIdentifier: selectedUnitIdentifier) != nil {
      selectUnit(withIdentifier: selectedUnitIdentifier, focus: false)
    } else {
      selectUnit(withIdentifier: work.text.identifier, focus: false)
    }
  }

  public func setSemanticEditingBlocked(_ blocked: Bool) {
    semanticEditingBlocked = blocked
    guard isViewLoaded else { return }
    unitTitle.isEditable = !blocked
    addButton.isEnabled = !blocked
    moveUpButton.isEnabled = !blocked && unitTable.selectedRow > 0
    moveDownButton.isEnabled =
      !blocked && unitTable.selectedRow >= 0
      && unitTable.selectedRow + 1 < work.manuscript.units.count
    for editor in editors.values { editor.setSemanticEditingBlocked(blocked) }
  }

  public var hasMarkedText: Bool { activeEditor?.textView?.hasMarkedText() ?? false }

  public func settleNativeEditing() {
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
  }

  @IBAction public func showHistory(_ sender: Any?) { historyRequested?() }

  private func applyManuscript(_ manuscript: Manuscript, selection: FolioIdentifier?, name: String) {
    guard !semanticEditingBlocked else { return }
    let before = work.manuscript
    let previousSelection = selectedUnitIdentifier
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
    documentUndoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated {
        target.applyManuscript(before, selection: previousSelection, name: name)
      }
    }
    work.manuscript = manuscript
    if let selection { selectUnit(withIdentifier: selection) }
    documentUndoManager.setActionName(name)
    workDidChange?()
    nativeEditingDidSettle?()
  }

  @IBAction public func addContentUnit(_ sender: Any?) {
    var units = work.manuscript.units
    let unit = TextUnit.makeEmpty()
    units.append(unit)
    applyManuscript(
      verifiedValue { try Manuscript(identifier: work.manuscriptIdentifier, units: units) },
      selection: unit.identifier,
      name: NSLocalizedString(
        "manuscript.add-content-unit.undo", tableName: nil, bundle: writeKitBundle,
        value: "Add Content Unit",
        comment:
          "Undo action name for adding a Content Unit to the Manuscript. AppKit adds Undo or Redo.")
    )
    view.window?.makeFirstResponder(unitTitle)
    unitTitle.selectText(nil)
  }

  @IBAction public func renameContentUnit(_ sender: Any?) {
    guard let selectedUnitIdentifier, let unit = work.text(withIdentifier: selectedUnitIdentifier)
    else { return }
    var title = unitTitle.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if title.isEmpty {
      title = NSLocalizedString(
        "content-unit.empty-title", tableName: nil, bundle: writeKitBundle,
        value: "Untitled",
        comment:
          "Title saved when the user submits an empty Content Unit title. Match the default title in FolioKit."
      )
    }
    guard unit.title != title else { return }
    var units = work.manuscript.units
    let index = units.firstIndex(where: { $0.identifier == unit.identifier })!
    units[index] = verifiedValue {
      try TextUnit(
        identifier: unit.identifier, title: title, paragraphs: unit.paragraphs,
        formattingWarningDismissed: unit.formattingWarningDismissed)
    }
    applyManuscript(
      verifiedValue { try Manuscript(identifier: work.manuscriptIdentifier, units: units) },
      selection: unit.identifier,
      name: NSLocalizedString(
        "manuscript.rename-content-unit.undo", tableName: nil, bundle: writeKitBundle,
        value: "Rename Content Unit",
        comment: "Undo action name for editing a Content Unit title; AppKit adds Undo or Redo."))
  }

  private func move(by delta: Int) {
    guard let selectedUnitIdentifier,
      let index = work.manuscript.units.firstIndex(where: {
        $0.identifier == selectedUnitIdentifier
      })
    else { return }
    let destination = index + delta
    guard work.manuscript.units.indices.contains(destination) else { return }
    var units = work.manuscript.units
    units.swapAt(index, destination)
    applyManuscript(
      verifiedValue { try Manuscript(identifier: work.manuscriptIdentifier, units: units) },
      selection: selectedUnitIdentifier,
      name: NSLocalizedString(
        "manuscript.reorder-content-unit.undo", tableName: nil, bundle: writeKitBundle,
        value: "Reorder Content Unit",
        comment: "Undo action name for moving a Content Unit; AppKit adds Undo or Redo."))
  }

  @IBAction public func moveContentUnitUp(_ sender: Any?) { move(by: -1) }
  @IBAction public func moveContentUnitDown(_ sender: Any?) { move(by: 1) }
}
