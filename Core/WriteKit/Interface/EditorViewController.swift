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
@MainActor public final class EditorViewController: NSViewController, NSTextViewDelegate {
  public var work: Work! {
    didSet {
      contentUnitIdentifier = work.text.identifier
      if isViewLoaded { displayWork() }
    }
  }
  public private(set) var contentUnitIdentifier: FolioIdentifier!
  public var textDidChange: (() -> Void)?
  public var undoDidChangeText: (() -> Void)?
  public var transientNativeEdit: (() -> Void)?
  public var nativeEditingDidSettle: (() -> Void)?
  public var historyRequested: (() -> Void)?
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

  public var unitText: TextUnit { work.text(withIdentifier: contentUnitIdentifier)! }

  public static func make(work: Work, undoManager: UndoManager) -> EditorViewController {
    make(work: work, contentUnitIdentifier: work.text.identifier, undoManager: undoManager)
  }

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

  @objc func didFinishUndoOrRedo(_ notification: Notification) {
    guard isViewLoaded, !loading, work.text(withIdentifier: contentUnitIdentifier) != nil else {
      return
    }
    let changed = !(capturedText?.isEqual(to: textView.textStorage ?? NSTextStorage()) ?? false)
    captureText()
    updateFormattingControls()
    if changed { undoDidChangeText?() }
  }

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

  public override func viewDidLoad() {
    super.viewDidLoad()
    guard let text = textView as? EditorTextView else {
      preconditionFailure("Missing Editor text view")
    }
    text.editor = self
    text.delegate = self
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

  public override func viewDidAppear() {
    super.viewDidAppear()
    if parent == nil && appearancePopover?.isShown != true {
      view.window?.makeFirstResponder(textView)
    }
  }
}
