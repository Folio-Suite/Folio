// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

/// Storyboard Manuscript sidebar with retained editors for one Work's Content Units.
///
/// The controller retains its Work and per-unit editors, all sharing the host's
/// undo manager. Calls and callbacks run on the main actor. Callback closures
/// are retained; capture a retaining host weakly to avoid cycles.
@MainActor
public final class ManuscriptViewController: NSViewController,
  NSTableViewDataSource, NSTableViewDelegate {
  /// Work presented by this controller. Reassignment removes all retained editors
  /// and clears selection before selecting the replacement Work's first unit.
  /// The host must settle native input and resolve its undo/history boundary first.
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
  /// Currently attached unit editor; absent until initial view setup selects a unit.
  public private(set) var activeEditor: EditorViewController!
  /// Transient sidebar selection, independent of the authored Manuscript order.
  public private(set) var selectedUnitIdentifier: FolioIdentifier?
  /// Monotonically increasing count of changes to the selected identity.
  /// Hosts can compare revisions to avoid replacing newer user navigation after asynchronous work.
  public private(set) var navigationRevision = 0
  /// Called synchronously after native content or a structural action changes
  /// provisional Work state. Durable hosts count changes only after history accepts them.
  public var workDidChange: (() -> Void)?
  /// Forwards the active editors' undoable transient typing-state notifications.
  public var transientNativeEdit: (() -> Void)?
  /// Called at native edit grouping and navigation boundaries to request host
  /// settlement. The callback itself does not wait for a durable transaction.
  public var nativeEditingDidSettle: (() -> Void)?
  /// Called when the sidebar or an editor requests the host's history presentation.
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

  /// Create the bundled sidebar/editor host with one shared undo boundary.
  /// - Parameters:
  ///   - work: The Work strongly retained by this controller.
  ///   - undoManager: Host-owned manager used by every retained unit editor.
  /// - Returns: A configured controller whose view is loaded on demand.
  /// A missing storyboard scene triggers a precondition failure.
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

  /// AppKit lifecycle hook that connects the loaded sidebar and selects the first unit.
  /// Hosts should use ``make(work:undoManager:)`` and let AppKit invoke this hook.
  public override func viewDidLoad() {
    super.viewDidLoad()
    addButton.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.add-content-unit", tableName: nil, bundle: writeKitBundle,
        value: "Add Content Unit",
        comment: "Accessibility label for adding a Content Unit to the Manuscript. "
            + "Content Unit and Manuscript are Folio domain terms."
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

  /// Load the bundled document window, attaching this controller and the active toolbar.
  /// - Returns: A new window controller for the host to retain and register with its document.
  /// Loads the sidebar view; a missing window scene triggers a precondition failure.
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

  /// NSTableView data-source hook returning the current flat Manuscript unit count.
  /// - Parameter tableView: The sidebar requesting its row count.
  public func numberOfRows(in tableView: NSTableView) -> Int { work.manuscript.units.count }

  /// NSTableView data-source hook returning the authored title for a sidebar row.
  /// - Parameters:
  ///   - tableView: The sidebar requesting a displayed value.
  ///   - tableColumn: The requesting column; this single-title presentation ignores it.
  ///   - row: A valid index in the current Manuscript.
  /// - Returns: The Content Unit title at that row.
  public func tableView(
    _ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?,
    row: Int
  ) -> Any? {
    work.manuscript.units[row].title
  }

  /// NSTableView delegate hook that attaches the selected unit's retained editor.
  /// - Parameter notification: The sidebar's selection-change notification.
  /// Programmatic selection synchronization is ignored to prevent recursive navigation.
  public func tableViewSelectionDidChange(_ notification: Notification) {
    guard !updatingSelection, unitTable.selectedRow >= 0 else { return }
    selectUnit(withIdentifier: work.manuscript.units[unitTable.selectedRow].identifier)
  }

  /// Select and attach an existing unit, retaining editors for later navigation and Undo.
  /// - Parameters:
  ///   - identifier: Unit to select; an absent identity leaves presentation unchanged.
  ///   - focus: Whether to make the selected text view first responder when a window exists.
  ///
  /// Breaks the previous editor's typing coalescing and requests host settlement before
  /// switching. Selection is transient and creates no authored history transaction.
  public func selectUnit(withIdentifier identifier: FolioIdentifier, focus: Bool = true) {
    guard let unit = work.text(withIdentifier: identifier) else { return }
    _ = view
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
    if selectedUnitIdentifier != identifier { navigationRevision += 1 }
    // Detach the view but keep its child controller and text storage alive:
    // native Undo actions may still target an editor for a nonvisible unit.
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
    // reloadData/selectRowIndexes can notify the delegate. Fence those callbacks
    // while projecting the selected identity into the table and title field.
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

  /// Fence text, title, add, and reorder controls during host history transitions.
  /// - Parameter blocked: Whether semantic changes should be refused.
  /// Propagates to retained editors; navigation and history presentation remain available.
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

  /// Whether the active editor contains provisional input-method composition.
  /// Returns `false` without a loaded active text view; hosts must defer durable settlement
  /// until marked input is resolved.
  public var hasMarkedText: Bool { activeEditor?.textView?.hasMarkedText() ?? false }

  /// Break the active editor's typing coalescing and invoke the settlement callback.
  /// Does not commit marked text, await durable acceptance, or force the title field to end editing.
  public func settleNativeEditing() {
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
  }

  /// Forward a native History action to ``historyRequested``; no history mutation occurs.
  @IBAction public func showHistory(_ sender: Any?) { historyRequested?() }

  private func applyManuscript(_ manuscript: Manuscript, selection: FolioIdentifier?, name: String) {
    guard !semanticEditingBlocked else { return }
    let before = work.manuscript
    let previousSelection = selectedUnitIdentifier
    activeEditor?.textView?.breakUndoCoalescing()
    nativeEditingDidSettle?()
    // UndoManager invokes the inverse on the same main-actor UI boundary.
    // Reentering this method records the reciprocal operation for native Redo.
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

  /// Append an empty Content Unit as an undoable provisional edit and select its title field.
  /// Semantic blocking prevents the authored change; the host accepts and saves it.
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

  /// Apply the title field to the selected unit as an undoable provisional edit.
  /// Trims surrounding whitespace and substitutes the localized Untitled title for
  /// an empty value. Missing selection, unchanged titles, or semantic blocking create no edit.
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

  /// Move the selected unit one position earlier as an undoable provisional edit.
  /// Does nothing at the beginning of the Manuscript or while semantic editing is blocked.
  @IBAction public func moveContentUnitUp(_ sender: Any?) { move(by: -1) }
  /// Move the selected unit one position later as an undoable provisional edit.
  /// Does nothing at the end of the Manuscript or while semantic editing is blocked.
  @IBAction public func moveContentUnitDown(_ sender: Any?) { move(by: 1) }
}

private extension ManuscriptViewController {
  func move(by delta: Int) {
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
}
