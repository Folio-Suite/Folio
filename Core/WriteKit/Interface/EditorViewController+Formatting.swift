// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

extension EditorViewController {
  func setFormattingWarningDismissed(_ dismissed: Bool) {
    guard !semanticEditingBlocked else { return }
    let previous = unitText.formattingWarningDismissed
    guard previous != dismissed else { return }
    editingUndoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated { target.setFormattingWarningDismissed(previous) }
    }
    let original = unitText
    work.replaceText(
      verifiedValue {
        try TextUnit(
          identifier: original.identifier, title: original.title,
          paragraphs: original.paragraphs, formattingWarningDismissed: dismissed)
      })
    updateFormattingWarning()
    textDidChange?()
  }

  @IBAction public func dismissFormattingWarning(_ sender: Any?) {
    formattingConflictPopover?.close()
    setFormattingWarningDismissed(true)
    editingUndoManager.setActionName(
      NSLocalizedString(
        "formatting.conflict.dismiss.undo", tableName: nil, bundle: writeKitBundle,
        value: "Dismiss Formatting Warning",
        comment: "Undo action name for dismissing a warning; AppKit adds Undo or Redo."))
    nativeEditingDidSettle?()
  }

  @IBAction public func convertPresentationToEmphasis(_ sender: Any?) {
    guard !semanticEditingBlocked else { return }
    formattingConflictPopover?.close()
    let convert: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
      guard hasFormattingConflict(attributes) else { return }
      let emphasis = modelEmphasis(attributes)
      let bold =
        (attributes[EditorAttribute.bold] as? NSNumber)?.boolValue == true
        || emphasisUsesBold(emphasis)
      let italic =
        (attributes[EditorAttribute.italic] as? NSNumber)?.boolValue == true
        || emphasisUsesItalic(emphasis)
      attributes[EditorAttribute.emphasis] =
        (bold && italic
        ? TextEmphasis.veryStrongEmphasis
        : (bold ? .strongEmphasis : .emphasis)).rawValue
      attributes[EditorAttribute.bold] = false
      attributes[EditorAttribute.italic] = false
      renderAttributes(&attributes)
    }
    let name = NSLocalizedString(
      "formatting.convert-to-emphasis.undo", tableName: nil, bundle: writeKitBundle,
      value: "Convert Presentation to Emphasis",
      comment: "Undo action name for converting visual Bold or Italic into semantic emphasis.")
    coordinatingFormattingGroup = true
    editingUndoManager.beginUndoGrouping()
    editAttributes(
      in: NSRange(location: 0, length: (textView.string as NSString).length), name: name,
      transform: convert)
    if textView.selectedRange.length == 0 && hasFormattingConflict(textView.typingAttributes) {
      var after = textView.typingAttributes
      convert(&after)
      applyTypingFormatting(after)
    }
    setFormattingWarningDismissed(true)
    editingUndoManager.setActionName(name)
    editingUndoManager.endUndoGrouping()
    coordinatingFormattingGroup = false
    nativeEditingDidSettle?()
    updateFormattingControls()
  }

  func applyTypingFormatting(_ attributes: [NSAttributedString.Key: Any]) {
    guard !semanticEditingBlocked else { return }
    transientNativeEdit?()
    let previous = textView.typingAttributes
    editingUndoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated { target.applyTypingFormatting(previous) }
    }
    textView.typingAttributes = attributes
    updateFormattingControls()
  }

  public func textViewDidChangeSelection(_ notification: Notification) {
    updateFormattingControls()
  }
  public func textViewDidChangeTypingAttributes(_ notification: Notification) {
    updateFormattingControls()
  }

  @IBAction public func toggleEmphasis(_ sender: Any?) {
    toggle(
      EditorAttribute.emphasis, value: TextEmphasis.emphasis.rawValue,
      name: NSLocalizedString(
        "formatting.emphasis.undo", tableName: nil, bundle: writeKitBundle,
        value: "Emphasis",
        comment:
          "Undo action name for applying semantic emphasis, distinct from visual Italic. AppKit adds Undo or Redo."
      ))
  }
  @IBAction public func toggleStrongEmphasis(_ sender: Any?) {
    toggle(
      EditorAttribute.emphasis, value: TextEmphasis.strongEmphasis.rawValue,
      name: NSLocalizedString(
        "formatting.strong-emphasis.undo", tableName: nil, bundle: writeKitBundle,
        value: "Strong Emphasis",
        comment:
          "Undo action name for applying strong semantic emphasis, distinct from visual Bold. AppKit adds Undo or Redo."
      ))
  }
  @IBAction public func toggleVeryStrongEmphasis(_ sender: Any?) {
    toggle(
      EditorAttribute.emphasis, value: TextEmphasis.veryStrongEmphasis.rawValue,
      name: NSLocalizedString(
        "formatting.very-strong-emphasis", tableName: nil, bundle: writeKitBundle,
        value: "Very Strong Emphasis",
        comment: "Undo action name for the strongest semantic emphasis level."))
  }
  @IBAction public func toggleBold(_ sender: Any?) {
    toggle(
      EditorAttribute.bold, value: 1,
      name: NSLocalizedString(
        "formatting.bold", tableName: nil, bundle: writeKitBundle,
        value: "Bold",
        comment:
          "Undo action name for visual bold formatting, distinct from semantic Strong Emphasis."))
  }
  @IBAction public func toggleItalic(_ sender: Any?) {
    toggle(
      EditorAttribute.italic, value: 1,
      name: NSLocalizedString(
        "formatting.italic", tableName: nil, bundle: writeKitBundle,
        value: "Italic",
        comment: "Undo action name for visual italic formatting, distinct from semantic Emphasis."))
  }
  @IBAction public func toggleUnderline(_ sender: Any?) {
    toggle(
      EditorAttribute.underline, value: 1,
      name: NSLocalizedString(
        "formatting.underline", tableName: nil, bundle: writeKitBundle,
        value: "Underline",
        comment: "Undo action name for visual underline formatting."))
  }
  @IBAction public func toggleStrikethrough(_ sender: Any?) {
    toggle(
      EditorAttribute.strikethrough, value: 1,
      name: NSLocalizedString(
        "formatting.strikethrough", tableName: nil, bundle: writeKitBundle,
        value: "Strikethrough",
        comment: "Undo action name for visual strikethrough formatting."))
  }

  @IBAction func showAppearance(_ sender: NSButton) {
    if appearancePopover?.isShown == true {
      appearancePopover?.performClose(sender)
      return
    }
    if appearancePopover == nil {
      guard
        let content = editorStoryboard().instantiateController(withIdentifier: "Appearance")
          as? AppearanceViewController
      else { preconditionFailure("Missing Appearance storyboard controller") }
      content.editor = self
      _ = content.view
      let popover = NSPopover()
      popover.behavior = .transient
      popover.contentViewController = content
      appearancePopover = popover
    }
    updateFormattingControls()
    appearancePopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }

  @IBAction func chooseEmphasis(_ sender: NSButton) {
    if NSEvent.modifierFlags.contains(.option) {
      toggleItalic(sender)
    } else {
      toggleEmphasis(sender)
    }
  }
  @IBAction func chooseStrongEmphasis(_ sender: NSButton) {
    if NSEvent.modifierFlags.contains(.option) {
      toggleBold(sender)
    } else {
      toggleStrongEmphasis(sender)
    }
  }
  @IBAction func showFormattingHelp(_ sender: NSButton) {
    if formattingHelp == nil {
      guard
        let content = editorStoryboard().instantiateController(withIdentifier: "FormattingHelp")
          as? NSViewController
      else { preconditionFailure("Missing Formatting Help storyboard controller") }
      let popover = NSPopover()
      popover.behavior = .transient
      popover.contentViewController = content
      formattingHelp = popover
    }
    formattingHelp?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }

  func toggle(_ key: NSAttributedString.Key, value: UInt, name: String) {
    guard !semanticEditingBlocked else { return }
    let remove = state(for: key, value: value) == .on
    let change: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
      attributes[key] = remove ? 0 : value
      renderAttributes(&attributes)
    }
    if textView.selectedRange.length == 0 {
      var attributes = textView.typingAttributes
      change(&attributes)
      textView.typingAttributes = attributes
      updateFormattingControls()
      if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
    } else {
      editAttributes(in: textView.selectedRange, name: name, transform: change)
    }
  }

  @IBAction public func clearFormatting(_ sender: Any?) {
    guard !semanticEditingBlocked else { return }
    let clear: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
      attributes[EditorAttribute.emphasis] = TextEmphasis.none.rawValue
      for key in [
        EditorAttribute.bold, EditorAttribute.italic,
        EditorAttribute.underline, EditorAttribute.strikethrough,
      ] { attributes[key] = false }
      renderAttributes(&attributes)
    }
    if textView.selectedRange.length == 0 {
      var attributes = textView.typingAttributes
      clear(&attributes)
      textView.typingAttributes = attributes
      updateFormattingControls()
      if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
    } else {
      editAttributes(
        in: textView.selectedRange,
        name: NSLocalizedString(
          "formatting.clear.undo", tableName: nil, bundle: writeKitBundle,
          value: "Clear Formatting",
          comment: "Undo action name for removing character formatting."), transform: clear)
    }
  }

  func editAttributes(
    in range: NSRange, name: String,
    transform: (inout [NSAttributedString.Key: Any]) -> Void
  ) {
    guard !semanticEditingBlocked else { return }
    guard range.length > 0, let storage = textView.textStorage else { return }
    let selection = textView.selectedRange
    let before = storage.attributedSubstring(from: range)
    let after = NSMutableAttributedString(attributedString: before)
    before.enumerateAttributes(
      in: NSRange(location: 0, length: before.length), options: []
    ) { attributes, subrange, _ in
      var changed = attributes
      transform(&changed)
      after.setAttributes(changed, range: subrange)
    }
    textView.breakUndoCoalescing()
    nativeEditingDidSettle?()
    applyFormatting(after, range: range, actionName: name)
    if !coordinatingFormattingGroup { nativeEditingDidSettle?() }
    textView.setSelectedRange(selection)
    if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
  }

  func applyFormatting(_ text: NSAttributedString, range: NSRange, actionName: String) {
    guard let storage = textView.textStorage else { return }
    let previous = storage.attributedSubstring(from: range)
    editingUndoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated {
        target.applyFormatting(previous, range: range, actionName: actionName)
      }
    }
    storage.beginEditing()
    text.enumerateAttributes(
      in: NSRange(location: 0, length: text.length), options: []
    ) { attributes, part, _ in
      storage.setAttributes(
        attributes, range: NSRange(location: range.location + part.location, length: part.length))
    }
    storage.endEditing()
    textView.didChangeText()
    editingUndoManager.setActionName(actionName)
  }

  func applyEmptyParagraphAttributes(_ attributes: [NSAttributedString.Key: Any]) {
    let previous = textView.typingAttributes
    editingUndoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated { target.applyEmptyParagraphAttributes(previous) }
    }
    textView.typingAttributes = attributes
    textView.didChangeText()
    editingUndoManager.setActionName(
      NSLocalizedString(
        "paragraph.alignment.undo", tableName: nil, bundle: writeKitBundle,
        value: "Paragraph Alignment",
        comment: "Undo action name for changing paragraph alignment."))
  }

  @IBAction func changeParagraphAlignment(_ sender: NSPopUpButton) {
    guard !semanticEditingBlocked else { return }
    let alignment = nativeAlignment(
      ParagraphAlignment(rawValue: UInt(sender.indexOfSelectedItem)) ?? .natural)
    let range = (textView.string as NSString).paragraphRange(for: textView.selectedRange)
    if range.length == 0 {
      var attributes = textView.typingAttributes
      let style =
        (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy()
        as? NSMutableParagraphStyle
        ?? NSMutableParagraphStyle()
      style.alignment = alignment
      attributes[.paragraphStyle] = style
      applyEmptyParagraphAttributes(attributes)
      nativeEditingDidSettle?()
    } else {
      editAttributes(
        in: range,
        name: NSLocalizedString(
          "paragraph.alignment.undo", tableName: nil, bundle: writeKitBundle,
          value: "Paragraph Alignment",
          comment: "Undo action name for changing paragraph alignment.")
      ) { attributes in
        let style =
          (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy()
          as? NSMutableParagraphStyle
          ?? NSMutableParagraphStyle()
        style.alignment = alignment
        attributes[.paragraphStyle] = style
      }
    }
    if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
  }
}
