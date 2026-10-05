// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

extension EditorViewController {
  func displayWork() {
    // Programmatic display must not be mistaken for native input by delegate
    // callbacks; loading brackets text storage, typing attributes, and selection.
    loading = true
    let text = NSMutableAttributedString(string: "")
    let paragraphs = unitText.paragraphs
    for (index, paragraph) in paragraphs.enumerated() {
      let start = text.length
      for run in paragraph.runs {
        text.append(
          NSAttributedString(
            string: run.string,
            attributes: editorAttributes(
              emphasis: run.emphasis,
              presentation: run.presentation, alignment: paragraph.alignment)))
      }
      if index + 1 < paragraphs.count {
        text.append(
          NSAttributedString(
            string: "\n",
            attributes: editorAttributes(
              emphasis: .none, presentation: .init(), alignment: paragraph.alignment)))
      }
      if text.length > start {
        text.addAttribute(
          EditorAttribute.paragraphIdentity, value: paragraph.identifier.rawValue,
          range: NSRange(location: start, length: text.length - start))
      }
    }
    textView.textStorage?.setAttributedString(text)
    trailingParagraphIdentifier = paragraphs.last?.identifier
    var typing = editorAttributes(
      emphasis: .none, presentation: .init(), alignment: paragraphs[0].alignment)
    typing[EditorAttribute.paragraphIdentity] = paragraphs[0].identifier.rawValue
    textView.typingAttributes = typing
    textView.setSelectedRange(NSRange(location: 0, length: 0))
    capturedText = textView.textStorage?.copy() as? NSAttributedString
    loading = false
    updateFormattingControls()
  }

  /// Refresh authored text after a finalized history operation without creating an
  /// editor change or moving the user's current selection to another Content Unit.
  /// The UTF-16 selection range is clamped to the refreshed text. An unloaded
  /// editor or a removed Content Unit is left untouched.
  public func refreshFromWork() {
    guard isViewLoaded, work.text(withIdentifier: contentUnitIdentifier) != nil else { return }
    let selection = textView.selectedRange
    editingUndoManager.disableUndoRegistration()
    displayWork()
    editingUndoManager.enableUndoRegistration()
    let end = (textView.string as NSString).length
    textView.setSelectedRange(
      NSRange(
        location: min(selection.location, end),
        length: min(selection.length, end - min(selection.location, end))))
  }

  /// Enable or fence native text and semantic actions during host history transitions.
  /// - Parameter blocked: `true` to make the text surface read-only and reject semantic actions.
  /// The semantic-action flag is retained before view loading. Load the view
  /// before calling when native text editability must also change. This does
  /// not settle pending input.
  public func setSemanticEditingBlocked(_ blocked: Bool) {
    semanticEditingBlocked = blocked
    if isViewLoaded { textView.isEditable = !blocked }
  }

  /// NSTextView delegate hook returning the host's shared manager for native editing.
  /// - Parameter view: The text view requesting an undo manager.
  /// - Returns: The manager supplied to the editor factory.
  /// Hosts should let AppKit request it rather than installing an independent text history.
  public func undoManager(for view: NSTextView) -> UndoManager? { editingUndoManager }

  /// NSText delegate hook that captures native text into the Work and refreshes formatting.
  /// - Parameter notification: The native text-change notification.
  /// Programmatic loading is ignored. The `textDidChange` closure reports provisional
  /// content; durable submission and document change counts remain host responsibilities.
  public func textDidChange(_ notification: Notification) {
    guard !loading else { return }
    captureText()
    updateFormattingControls()
    textDidChange?()
  }

  func captureText() {
    guard let storage = textView.textStorage,
      work.text(withIdentifier: contentUnitIdentifier) != nil
    else { return }
    let original = unitText
    let source = storage.string as NSString
    let paragraphs = captureParagraphs(storage: storage, source: source, original: original)
    trailingParagraphIdentifier = paragraphs.last?.identifier
    work.replaceText(
      verifiedValue {
        try TextUnit(
          identifier: original.identifier, title: original.title,
          paragraphs: paragraphs, formattingWarningDismissed: original.formattingWarningDismissed)
      })
    if textView.selectedRange.location == storage.length, let trailingParagraphIdentifier {
      var attributes = textView.typingAttributes
      attributes[EditorAttribute.paragraphIdentity] = trailingParagraphIdentifier.rawValue
      textView.typingAttributes = attributes
    }
    capturedText = storage.copy() as? NSAttributedString
  }

  private func captureParagraphs(
    storage: NSTextStorage, source: NSString, original: TextUnit
  ) -> [TextParagraph] {
    let lines = storage.string.components(separatedBy: "\n")
    var paragraphs: [TextParagraph] = []
    var identifiers: Set<FolioIdentifier> = []
    var offset = 0
    for (index, line) in lines.enumerated() {
      let content = NSRange(location: offset, length: (line as NSString).length)
      let whole = NSRange(
        location: offset, length: content.length + (index + 1 < lines.count ? 1 : 0))
      let attributes =
        offset < storage.length
        ? storage.attributes(at: offset, effectiveRange: nil)
        : textView.typingAttributes
      let rawIdentity =
        whole.length > 0
        ? attributes[EditorAttribute.paragraphIdentity] as? String
        : (storage.length > 0
          ? trailingParagraphIdentifier?.rawValue : original.paragraphs.first?.identifier.rawValue)
      var identity = rawIdentity.flatMap { try? FolioIdentifier(rawValue: $0) } ?? .make()
      // Native paragraph splits can inherit the original paragraph attribute.
      // Reuse the first occurrence and mint identities for duplicates, preserving
      // the Manuscript's uniqueness invariant after typing or paste.
      if identifiers.contains(identity) { identity = .make() }
      identifiers.insert(identity)
      var runs: [TextRun] = []
      if content.length > 0 {
        storage.enumerateAttributes(in: content, options: []) { attributes, range, _ in
          let run = TextRun(
            string: source.substring(with: range), emphasis: modelEmphasis(attributes),
            presentation: modelPresentation(attributes))
          if let previous = runs.last, previous.emphasis == run.emphasis,
            previous.presentation == run.presentation {
            runs[runs.count - 1] = TextRun(
              string: previous.string + run.string,
              emphasis: run.emphasis, presentation: run.presentation)
          } else {
            runs.append(run)
          }
        }
      }
      let style = attributes[.paragraphStyle] as? NSParagraphStyle
      paragraphs.append(
        TextParagraph(
          identifier: identity, runs: runs,
          alignment: modelAlignment(style?.alignment ?? .natural)))
      if whole.length > 0 {
        storage.addAttribute(
          EditorAttribute.paragraphIdentity, value: identity.rawValue, range: whole)
      }
      offset += whole.length
    }
    return paragraphs
  }

  func state(for key: NSAttributedString.Key, value expected: UInt) -> NSControl.StateValue {
    let selection = textView.selectedRange
    if selection.length == 0 {
      return (textView.typingAttributes[key] as? NSNumber)?.uintValue == expected ? .on : .off
    }
    var any = false
    var all = true
    textView.textStorage?.enumerateAttribute(key, in: selection, options: []) { value, _, _ in
      let enabled = (value as? NSNumber)?.uintValue == expected
      any = any || enabled
      all = all && enabled
    }
    return all ? .on : (any ? .mixed : .off)
  }

  func updateFormattingControls() {
    if parent != nil && view.superview == nil {
      updateFormattingWarning()
      return
    }
    guard !loading, isViewLoaded else { return }
    emphasisButton?.state = state(
      for: EditorAttribute.emphasis, value: TextEmphasis.emphasis.rawValue)
    strongButton?.state = state(
      for: EditorAttribute.emphasis, value: TextEmphasis.strongEmphasis.rawValue)
    if let appearance = appearancePopover?.contentViewController as? AppearanceViewController,
      appearance.isViewLoaded {
      let buttons = [
        appearance.boldButton, appearance.italicButton,
        appearance.underlineButton, appearance.strikethroughButton,
      ]
      let keys = [
        EditorAttribute.bold, EditorAttribute.italic,
        EditorAttribute.underline, EditorAttribute.strikethrough,
      ]
      for (button, key) in zip(buttons, keys) { button?.state = state(for: key, value: 1) }
    }
    let index = textView.selectedRange.location
    let style =
      index < (textView.string as NSString).length
      ? textView.textStorage?.attribute(.paragraphStyle, at: index, effectiveRange: nil)
        as? NSParagraphStyle
      : textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
    alignmentButton?.selectItem(at: Int(modelAlignment(style?.alignment ?? .natural).rawValue))
    updateFormattingWarning()
  }

  func updateFormattingWarning() {
    guard let layout = textView.layoutManager, let storage = textView.textStorage else { return }
    let whole = NSRange(location: 0, length: (textView.string as NSString).length)
    // Layout-manager temporary attributes affect display only. Keeping warnings
    // out of text storage prevents copy/paste and native saving from authoring them.
    layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
    var ranges: [NSRange] = []
    if !unitText.formattingWarningDismissed {
      storage.enumerateAttributes(in: whole, options: []) { attributes, range, _ in
        guard hasFormattingConflict(attributes) else { return }
        layout.addTemporaryAttribute(
          .backgroundColor,
          value: NSColor.systemYellow.withAlphaComponent(0.3), forCharacterRange: range)
        if let previous = ranges.last, NSMaxRange(previous) == range.location {
          ranges[ranges.count - 1] = NSUnionRange(previous, range)
        } else {
          ranges.append(range)
        }
      }
    }
    if ranges != formattingConflictRanges { formattingConflictPopover?.close() }
    formattingConflictRanges = ranges
    layoutFormattingMarkers()
  }

  func layoutFormattingMarkers() {
    guard isViewLoaded, !loading, !layingOutFormattingMarkers,
      let layout = textView.layoutManager, let container = textView.textContainer
    else { return }
    // ensureLayout can cause geometry callbacks. Fence reentry while measuring
    // glyph lines and moving marker subviews using text-container coordinates.
    layingOutFormattingMarkers = true
    defer { layingOutFormattingMarkers = false }
    layout.ensureLayout(for: container)
    let frames = formattingMarkerFrames(layout: layout)
    updateFormattingMarkerCount(frames.count)
    for (marker, frame) in zip(formattingMarkers, frames) { marker.view.frame = frame }
  }

  private func formattingMarkerFrames(layout: NSLayoutManager) -> [NSRect] {
    var frames: [NSRect] = []
    var markedLines: Set<Int> = []
    let origin = textView.textContainerOrigin
    for range in formattingConflictRanges {
      guard range.length > 0, NSMaxRange(range) <= (textView.string as NSString).length else {
        continue
      }
      let glyph = layout.glyphIndexForCharacter(at: NSMaxRange(range) - 1)
      var lineRange = NSRange()
      let line = layout.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: &lineRange)
      guard markedLines.insert(lineRange.location).inserted else { continue }
      var frame = NSRect(
        x: origin.x + line.maxX + 3, y: origin.y + line.midY - 10, width: 20, height: 20)
      frame.origin.x = min(frame.origin.x, textView.bounds.maxX - 22)
      frames.append(frame)
    }
    return frames
  }

  private func updateFormattingMarkerCount(_ count: Int) {
    while formattingMarkers.count > count {
      formattingConflictPopover?.close()
      formattingMarkers.removeLast().view.removeFromSuperview()
    }
    while formattingMarkers.count < count {
      formattingMarkers.append(makeFormattingMarker())
    }
  }

  private func makeFormattingMarker() -> FormattingWarningViewController {
    guard
      let marker = editorStoryboard().instantiateController(
        withIdentifier: "FormattingConflictMarker")
        as? FormattingWarningViewController
    else { preconditionFailure("Missing formatting marker") }
    marker.editor = self
    _ = marker.view
    marker.markerButton.contentTintColor = .systemOrange
    marker.markerButton.setAccessibilityLabel(
      NSLocalizedString(
        "formatting.conflict.accessibility-label", tableName: nil, bundle: writeKitBundle,
        value: "Formatting conflict",
        comment: "Accessibility name of the inline warning marker."))
    marker.markerButton.setAccessibilityHelp(
      NSLocalizedString(
        "formatting.conflict.accessibility-help", tableName: nil, bundle: writeKitBundle,
        value: "Bold or Italic overlaps semantic emphasis. Show conversion and dismissal options.",
        comment: "Accessibility help for the formatting conflict marker; "
            + "Bold and Italic are appearance choices."
      ))
    marker.markerButton.identifier = NSUserInterfaceItemIdentifier("formattingConflictMarker")
    textView.addSubview(marker.view)
    return marker
  }

  func showInlineFormattingWarning(_ sender: NSButton) {
    if formattingConflictPopover == nil {
      guard
        let content = editorStoryboard().instantiateController(withIdentifier: "FormattingConflict")
          as? FormattingWarningViewController
      else { preconditionFailure("Missing formatting warning") }
      content.editor = self
      let popover = NSPopover()
      popover.behavior = .transient
      popover.contentViewController = content
      formattingConflictPopover = popover
    }
    formattingConflictPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }
}
