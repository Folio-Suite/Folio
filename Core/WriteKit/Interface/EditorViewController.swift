// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

final class WriteKitBundleToken {}
let writeKitBundle =
  Bundle(identifier: "dev.foliosuite.WriteKit") ?? Bundle(for: WriteKitBundleToken.self)

func editorStoryboard() -> NSStoryboard {
  NSStoryboard(name: "Editor", bundle: writeKitBundle)
}

/// Native text editing for one Content Unit. The Work owns authored values and the host owns saving.
///
/// Construct with a factory so the storyboard, Work, and shared undo manager
/// are configured together. Calls and callbacks run on the main actor.
/// Callback closures are retained; capture a retaining host weakly to avoid cycles.
@MainActor public final class EditorViewController: NSViewController, NSTextViewDelegate {
  /// The strongly retained Work being edited.
  /// Assigning a different Work selects its first Content Unit and redisplays a loaded
  /// view. Settle editing and resolve the host's undo/history boundary before replacing it.
  public var work: Work! {
    didSet {
      contentUnitIdentifier = work.text.identifier
      if isViewLoaded { displayWork() }
    }
  }
  /// Identity of the Content Unit bound by the factory; assigning ``work`` resets it to the first unit.
  public private(set) var contentUnitIdentifier: FolioIdentifier!
  /// Called synchronously after native text or semantic formatting has updated the
  /// Work's provisional snapshot. The host must settle and accept durable history
  /// before treating this notification as an authoritative document change.
  public var textDidChange: (() -> Void)?
  /// Called after the shared undo manager finishes Undo or Redo and this editor
  /// observes changed text storage. A Manuscript host uses it to reveal the affected unit.
  public var undoDidChangeText: (() -> Void)?
  /// Called before an explicitly undoable typing-attribute change. This transient
  /// state does not by itself change authored Work content.
  public var transientNativeEdit: (() -> Void)?
  /// Called at native grouping boundaries so the host can submit settled provisional
  /// content. This synchronous notification does not await durable acceptance.
  public var nativeEditingDidSettle: (() -> Void)?
  /// Called when the native History action is routed to this editor. The host presents history.
  public var historyRequested: (() -> Void)?
  /// Storyboard-owned text surface, available after the controller's view is loaded.
  /// Its delegate and undo manager are configured by WriteKit; edits are main-actor isolated.
  @IBOutlet public private(set) var textView: NSTextView!
  @IBOutlet var alignmentButton: NSPopUpButton!
  @IBOutlet var emphasisButton: NSButton!
  @IBOutlet var strongButton: NSButton!
  @IBOutlet var clearButton: NSButton!
  @IBOutlet var helpButton: NSButton!

  var editingUndoManager: UndoManager!
  var capturedText: NSAttributedString?
  var trailingParagraphIdentifier: FolioIdentifier?
  var loading = false
  var semanticEditingBlocked = false
  var coordinatingFormattingGroup = false
  var formattingButtons: [NSButton] = []
  var formattingHelp: NSPopover?
  var formattingConflictRanges: [NSRange] = []
  var formattingMarkers: [FormattingWarningViewController] = []
  var formattingConflictPopover: NSPopover?
  var layingOutFormattingMarkers = false
  var appearancePopover: NSPopover?

  /// Current value of the bound Content Unit. The Work must still contain
  /// ``contentUnitIdentifier``; removing that identity before access violates the binding.
  public var unitText: TextUnit { work.text(withIdentifier: contentUnitIdentifier)! }

  /// Create a storyboard editor bound to the Work's first Content Unit.
  /// - Parameters:
  ///   - work: Work retained by the editor.
  ///   - undoManager: Host-owned manager shared across this Work's editors.
  /// - Returns: A configured editor whose view is loaded on demand.
  public static func make(work: Work, undoManager: UndoManager) -> EditorViewController {
    make(work: work, contentUnitIdentifier: work.text.identifier, undoManager: undoManager)
  }

  /// Create a storyboard editor for an existing Content Unit.
  /// - Parameters:
  ///   - work: Work retained by the editor.
  ///   - contentUnitIdentifier: Identity present in the Work's current Manuscript.
  ///   - undoManager: Host-owned manager shared across this Work's editors.
  /// - Returns: A configured editor whose view is loaded on demand.
  ///
  /// A missing Content Unit or bundled storyboard scene triggers a precondition failure.
  /// With durable history, supply the native router's provisional undo manager.
  public static func make(
    work: Work, contentUnitIdentifier: FolioIdentifier,
    undoManager: UndoManager
  ) -> EditorViewController {
    precondition(work.text(withIdentifier: contentUnitIdentifier) != nil)
    guard
      let controller = editorStoryboard().instantiateController(withIdentifier: "Editor")
        as? EditorViewController
    else {
      preconditionFailure("Missing Editor storyboard controller")
    }
    controller.configure(
      work: work, contentUnitIdentifier: contentUnitIdentifier, undoManager: undoManager)
    return controller
  }

  required init?(coder: NSCoder) { super.init(coder: coder) }

  deinit { NotificationCenter.default.removeObserver(self) }

  func configure(
    work: Work, contentUnitIdentifier: FolioIdentifier, undoManager: UndoManager
  ) {
    self.work = work
    self.contentUnitIdentifier = contentUnitIdentifier
    self.editingUndoManager = undoManager
    NotificationCenter.default.addObserver(
      self, selector: #selector(didFinishUndoOrRedo(_:)),
      name: .NSUndoManagerDidUndoChange, object: undoManager)
    NotificationCenter.default.addObserver(
      self, selector: #selector(didFinishUndoOrRedo(_:)),
      name: .NSUndoManagerDidRedoChange, object: undoManager)
  }

  // UndoManager sends these notifications after replay finishes. Capture once
  // at that boundary so the host sees the resulting state, not intermediate edits.
  @objc func didFinishUndoOrRedo(_ notification: Notification) {
    guard isViewLoaded, !loading, work.text(withIdentifier: contentUnitIdentifier) != nil else {
      return
    }
    let changed = !(capturedText?.isEqual(to: textView.textStorage ?? NSTextStorage()) ?? false)
    captureText()
    updateFormattingControls()
    if changed { undoDidChangeText?() }
  }

  /// Load WriteKit's reusable document window and connect its toolbar to this editor.
  /// - Returns: A new window controller retaining this editor as its content controller.
  ///
  /// The host must retain and register the window controller with its document.
  /// This loads the editor view; a missing storyboard scene is a precondition failure.
  public func makeWindowController() -> NSWindowController {
    guard
      let controller = editorStoryboard().instantiateController(withIdentifier: "EditorWindow")
        as? EditorWindowController
    else {
      preconditionFailure("Missing Editor Window storyboard controller")
    }
    connectToolbar(controller)
    controller.contentViewController = self
    _ = view
    updateFormattingControls()
    return controller
  }

  // Toolbar outlets belong to the window scene, not the editor scene. Rebind
  // them when a Manuscript host switches editors so controls show the active unit.
  func connectToolbar(_ controller: NSWindowController) {
    guard let controller = controller as? EditorWindowController else { return }
    emphasisButton = controller.emphasisButton
    strongButton = controller.strongButton
    clearButton = controller.clearButton
    helpButton = controller.helpButton
    alignmentButton = controller.alignmentButton
    formattingButtons = [emphasisButton, strongButton]
    emphasisButton.setAccessibilityLabel(
      NSLocalizedString(
        "formatting.emphasis", tableName: nil, bundle: writeKitBundle,
        value: "Emphasis",
        comment: "Accessibility label for semantic emphasis, distinct from visual Italic."))
    strongButton.setAccessibilityLabel(
      NSLocalizedString(
        "formatting.strong-emphasis", tableName: nil, bundle: writeKitBundle,
        value: "Strong Emphasis",
        comment: "Accessibility label for strong semantic emphasis, distinct from visual Bold."))
    for button in formattingButtons { button.setAccessibilityHelp(button.toolTip) }
    clearButton.setAccessibilityLabel(
      NSLocalizedString(
        "formatting.clear.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Clear character formatting",
        comment:
          "Accessibility label for removing semantic and visual character formatting, preserving paragraph alignment."
      ))
    helpButton.setAccessibilityLabel(
      NSLocalizedString(
        "formatting.help.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Formatting help",
        comment: "Accessibility label for opening help about semantic and visual formatting."))
    alignmentButton.setAccessibilityLabel(
      NSLocalizedString(
        "paragraph.alignment.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Paragraph alignment",
        comment: "Accessibility label of the paragraph alignment control."))
    updateFormattingControls()
  }

  /// AppKit lifecycle hook that wires the storyboard text view after its outlets load.
  /// Hosts should use the factories and let AppKit invoke this hook.
  public override func viewDidLoad() {
    super.viewDidLoad()
    guard let text = textView as? EditorTextView else {
      preconditionFailure("Missing Editor text view")
    }
    text.editor = self
    text.delegate = self
    // TextKit wraps to the view width while allowing the document to grow
    // vertically; warning-marker geometry uses this same layout manager.
    text.textContainer?.widthTracksTextView = true
    text.textContainer?.containerSize = NSSize(
      width: text.bounds.width, height: .greatestFiniteMagnitude)
    text.isAutomaticQuoteSubstitutionEnabled = false
    text.isAutomaticDashSubstitutionEnabled = false
    text.setAccessibilityLabel(
      NSLocalizedString(
        "manuscript.text.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Manuscript text",
        comment: "Accessibility name of the editable Manuscript text area."))
    text.identifier = NSUserInterfaceItemIdentifier("manuscriptText")
    if work != nil { displayWork() }
  }

  /// AppKit lifecycle hook that focuses a standalone editor after it appears.
  /// An embedded Manuscript editor lets its parent own focus; an open Appearance
  /// popover keeps its current responder. Hosts should let AppKit invoke this hook.
  public override func viewDidAppear() {
    super.viewDidAppear()
    if parent == nil && appearancePopover?.isShown != true {
      view.window?.makeFirstResponder(textView)
    }
  }
}
