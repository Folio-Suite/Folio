// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

/// Storyboard window chrome routes toolbar commands to the active Content Unit.
@MainActor final class EditorWindowController: NSWindowController {
  @IBOutlet var emphasisButton: NSButton!
  @IBOutlet var strongButton: NSButton!
  @IBOutlet var clearButton: NSButton!
  @IBOutlet var helpButton: NSButton!
  @IBOutlet var alignmentButton: NSPopUpButton!

  override func windowDidLoad() {
    super.windowDidLoad()
    installSemanticImages()
  }

  func installSemanticImages() {
    for (identifier, image, button) in [
      ("dev.foliosuite.Write.emphasis", FormattingImages.emphasis, emphasisButton!),
      ("dev.foliosuite.Write.strong", FormattingImages.strongEmphasis, strongButton!),
    ] {
      button.image = image
      window?.toolbar?.items.first(where: { $0.itemIdentifier.rawValue == identifier })?.image =
        image
    }
  }

  var formattingEditor: EditorViewController? {
    if let manuscript = contentViewController as? ManuscriptViewController {
      return manuscript.activeEditor
    }
    return contentViewController as? EditorViewController
  }
  @IBAction func showAppearance(_ sender: NSButton) { formattingEditor?.showAppearance(sender) }
  @IBAction func chooseEmphasis(_ sender: NSButton) { formattingEditor?.chooseEmphasis(sender) }
  @IBAction func chooseStrongEmphasis(_ sender: NSButton) {
    formattingEditor?.chooseStrongEmphasis(sender)
  }
  @IBAction func clearFormatting(_ sender: Any?) { formattingEditor?.clearFormatting(sender) }
  @IBAction func changeParagraphAlignment(_ sender: NSPopUpButton) {
    formattingEditor?.changeParagraphAlignment(sender)
  }
  @IBAction func showFormattingHelp(_ sender: NSButton) {
    formattingEditor?.showFormattingHelp(sender)
  }
}

@MainActor final class AppearanceViewController: NSViewController {
  weak var editor: EditorViewController?
  @IBOutlet var boldButton: NSButton!
  @IBOutlet var italicButton: NSButton!
  @IBOutlet var underlineButton: NSButton!
  @IBOutlet var strikethroughButton: NSButton!
  @IBAction func toggleBold(_ sender: Any?) { editor?.toggleBold(sender) }
  @IBAction func toggleItalic(_ sender: Any?) { editor?.toggleItalic(sender) }
  @IBAction func toggleUnderline(_ sender: Any?) { editor?.toggleUnderline(sender) }
  @IBAction func toggleStrikethrough(_ sender: Any?) { editor?.toggleStrikethrough(sender) }
}

@MainActor final class FormattingWarningViewController: NSViewController {
  weak var editor: EditorViewController?
  @IBOutlet var markerButton: NSButton!
  @IBAction func showWarning(_ sender: NSButton) { editor?.showInlineFormattingWarning(sender) }
  @IBAction func convertPresentationToEmphasis(_ sender: Any?) {
    editor?.convertPresentationToEmphasis(sender)
  }
  @IBAction func dismissFormattingWarning(_ sender: Any?) {
    editor?.dismissFormattingWarning(sender)
  }
}
