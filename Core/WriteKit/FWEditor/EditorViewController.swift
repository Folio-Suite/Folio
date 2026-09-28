// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

private final class WriteKitBundleToken {}
let writeKitBundle = Bundle(identifier: "dev.foliosuite.WriteKit") ?? Bundle(for: WriteKitBundleToken.self)

func writeString(_ key: String, _ value: String, _ comment: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: writeKitBundle, value: value, comment: comment)
}

private func editorStoryboard() -> NSStoryboard { NSStoryboard(name: "Editor", bundle: writeKitBundle) }

/// Native text editing for one Content Unit. The Work owns authored values and the host owns saving.
@MainActor @objc(FWEditorViewController) public final class EditorViewController: NSViewController, NSTextViewDelegate {
    public var work: Work! {
        didSet {
            contentUnitIdentifier = work.text.identifier
            if isViewLoaded { displayWork() }
        }
    }
    public private(set) var contentUnitIdentifier: FolioIdentifier!
    public var textDidChange: (() -> Void)?
    public var undoDidChangeText: (() -> Void)?
    @IBOutlet public private(set) var textView: NSTextView!
    @IBOutlet private var alignmentButton: NSPopUpButton!
    @IBOutlet private var emphasisButton: NSButton!
    @IBOutlet private var strongButton: NSButton!
    @IBOutlet private var clearButton: NSButton!
    @IBOutlet private var helpButton: NSButton!

    private var editingUndoManager: UndoManager!
    private var capturedText: NSAttributedString?
    private var trailingParagraphIdentifier: FolioIdentifier?
    private var loading = false
    private var formattingButtons: [NSButton] = []
    private var formattingHelp: NSPopover?
    private var formattingConflictRanges: [NSRange] = []
    var formattingMarkers: [FormattingWarningViewController] = []
    private var formattingConflictPopover: NSPopover?
    private var layingOutFormattingMarkers = false
    var appearancePopover: NSPopover?

    public var unitText: TextUnit { work.text(withIdentifier: contentUnitIdentifier)! }

    public static func make(work: Work, undoManager: UndoManager) -> EditorViewController {
        make(work: work, contentUnitIdentifier: work.text.identifier, undoManager: undoManager)
    }

    public static func make(work: Work, contentUnitIdentifier: FolioIdentifier,
                            undoManager: UndoManager) -> EditorViewController {
        precondition(work.text(withIdentifier: contentUnitIdentifier) != nil)
        guard let controller = editorStoryboard().instantiateController(withIdentifier: "Editor") as? EditorViewController else {
            preconditionFailure("Missing Editor storyboard controller")
        }
        controller.configure(work: work, contentUnitIdentifier: contentUnitIdentifier, undoManager: undoManager)
        return controller
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func configure(work: Work, contentUnitIdentifier: FolioIdentifier, undoManager: UndoManager) {
        self.work = work
        self.contentUnitIdentifier = contentUnitIdentifier
        self.editingUndoManager = undoManager
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishUndoOrRedo(_:)),
            name: .NSUndoManagerDidUndoChange, object: undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishUndoOrRedo(_:)),
            name: .NSUndoManagerDidRedoChange, object: undoManager)
    }

    @objc private func didFinishUndoOrRedo(_ notification: Notification) {
        guard isViewLoaded, !loading, work.text(withIdentifier: contentUnitIdentifier) != nil else { return }
        let changed = !(capturedText?.isEqual(to: textView.textStorage ?? NSTextStorage()) ?? false)
        captureText()
        updateFormattingControls()
        if changed { undoDidChangeText?() }
    }

    public func makeWindowController() -> NSWindowController {
        guard let controller = editorStoryboard().instantiateController(withIdentifier: "EditorWindow") as? EditorWindowController else {
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
        emphasisButton.setAccessibilityLabel(writeString("formatting.emphasis", "Emphasis",
            "Accessibility label for semantic emphasis, distinct from visual Italic."))
        strongButton.setAccessibilityLabel(writeString("formatting.strong-emphasis", "Strong Emphasis",
            "Accessibility label for strong semantic emphasis, distinct from visual Bold."))
        for button in formattingButtons { button.setAccessibilityHelp(button.toolTip) }
        clearButton.setAccessibilityLabel(writeString("formatting.clear.accessibility-label", "Clear character formatting",
            "Accessibility label for removing semantic and visual character formatting, preserving paragraph alignment."))
        helpButton.setAccessibilityLabel(writeString("formatting.help.accessibility-label", "Formatting help",
            "Accessibility label for opening help about semantic and visual formatting."))
        alignmentButton.setAccessibilityLabel(writeString("paragraph.alignment.accessibility-label", "Paragraph alignment",
            "Accessibility label of the paragraph alignment control."))
        updateFormattingControls()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        guard let text = textView as? EditorTextView else { preconditionFailure("Missing Editor text view") }
        text.editor = self
        text.delegate = self
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: text.bounds.width, height: .greatestFiniteMagnitude)
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.setAccessibilityLabel(writeString("manuscript.text.accessibility-label", "Manuscript text",
            "Accessibility name of the editable Manuscript text area."))
        text.identifier = NSUserInterfaceItemIdentifier("manuscriptText")
        if work != nil { displayWork() }
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        if parent == nil && appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
    }
}

extension EditorViewController {
    private func displayWork() {
        loading = true
        let text = NSMutableAttributedString(string: "")
        let paragraphs = unitText.paragraphs
        for (index, paragraph) in paragraphs.enumerated() {
            let start = text.length
            for run in paragraph.runs {
                text.append(NSAttributedString(string: run.string,
                    attributes: editorAttributes(emphasis: run.emphasis,
                                                 presentation: run.presentation, alignment: paragraph.alignment)))
            }
            if index + 1 < paragraphs.count {
                text.append(NSAttributedString(string: "\n",
                    attributes: editorAttributes(emphasis: .none, presentation: .init(), alignment: paragraph.alignment)))
            }
            if text.length > start {
                text.addAttribute(EditorAttribute.paragraphIdentity, value: paragraph.identifier.rawValue,
                    range: NSRange(location: start, length: text.length - start))
            }
        }
        textView.textStorage?.setAttributedString(text)
        trailingParagraphIdentifier = paragraphs.last?.identifier
        var typing = editorAttributes(emphasis: .none, presentation: .init(), alignment: paragraphs[0].alignment)
        typing[EditorAttribute.paragraphIdentity] = paragraphs[0].identifier.rawValue
        textView.typingAttributes = typing
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        capturedText = textView.textStorage?.copy() as? NSAttributedString
        loading = false
        updateFormattingControls()
    }

    public func undoManager(for view: NSTextView) -> UndoManager? { editingUndoManager }

    public func textDidChange(_ notification: Notification) {
        guard !loading else { return }
        captureText()
        updateFormattingControls()
        textDidChange?()
    }

    private func captureText() {
        guard let storage = textView.textStorage, work.text(withIdentifier: contentUnitIdentifier) != nil else { return }
        let original = unitText
        let source = storage.string as NSString
        let lines = storage.string.components(separatedBy: "\n")
        var paragraphs: [TextParagraph] = []
        var identifiers: Set<FolioIdentifier> = []
        var offset = 0
        for (index, line) in lines.enumerated() {
            let content = NSRange(location: offset, length: (line as NSString).length)
            let whole = NSRange(location: offset, length: content.length + (index + 1 < lines.count ? 1 : 0))
            let attributes = offset < storage.length ? storage.attributes(at: offset, effectiveRange: nil)
                                                    : textView.typingAttributes
            let rawIdentity = whole.length > 0 ? attributes[EditorAttribute.paragraphIdentity] as? String
                : (storage.length > 0 ? trailingParagraphIdentifier?.rawValue : original.paragraphs.first?.identifier.rawValue)
            var identity = rawIdentity.flatMap { try? FolioIdentifier(rawValue: $0) } ?? .make()
            if identifiers.contains(identity) { identity = .make() }
            identifiers.insert(identity)
            var runs: [TextRun] = []
            if content.length > 0 {
                storage.enumerateAttributes(in: content, options: []) { attributes, range, _ in
                    let run = TextRun(string: source.substring(with: range), emphasis: modelEmphasis(attributes),
                                      presentation: modelPresentation(attributes))
                    if let previous = runs.last, previous.emphasis == run.emphasis,
                       previous.presentation == run.presentation {
                        runs[runs.count - 1] = TextRun(string: previous.string + run.string,
                                                      emphasis: run.emphasis, presentation: run.presentation)
                    } else { runs.append(run) }
                }
            }
            let style = attributes[.paragraphStyle] as? NSParagraphStyle
            paragraphs.append(TextParagraph(identifier: identity, runs: runs,
                                             alignment: modelAlignment(style?.alignment ?? .natural)))
            if whole.length > 0 {
                storage.addAttribute(EditorAttribute.paragraphIdentity, value: identity.rawValue, range: whole)
            }
            offset += whole.length
        }
        trailingParagraphIdentifier = paragraphs.last?.identifier
        work.replaceText(verifiedValue { try TextUnit(identifier: original.identifier, title: original.title,
            paragraphs: paragraphs, formattingWarningDismissed: original.formattingWarningDismissed) })
        if textView.selectedRange.location == storage.length, let trailingParagraphIdentifier {
            var attributes = textView.typingAttributes
            attributes[EditorAttribute.paragraphIdentity] = trailingParagraphIdentifier.rawValue
            textView.typingAttributes = attributes
        }
        capturedText = storage.copy() as? NSAttributedString
    }

    private func state(for key: NSAttributedString.Key, value expected: UInt) -> NSControl.StateValue {
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

    private func updateFormattingControls() {
        if parent != nil && view.superview == nil { updateFormattingWarning(); return }
        guard !loading, isViewLoaded else { return }
        emphasisButton?.state = state(for: EditorAttribute.emphasis, value: TextEmphasis.emphasis.rawValue)
        strongButton?.state = state(for: EditorAttribute.emphasis, value: TextEmphasis.strongEmphasis.rawValue)
        if let appearance = appearancePopover?.contentViewController as? AppearanceViewController, appearance.isViewLoaded {
            let buttons = [appearance.boldButton, appearance.italicButton,
                           appearance.underlineButton, appearance.strikethroughButton]
            let keys = [EditorAttribute.bold, EditorAttribute.italic,
                        EditorAttribute.underline, EditorAttribute.strikethrough]
            for (button, key) in zip(buttons, keys) { button?.state = state(for: key, value: 1) }
        }
        let index = textView.selectedRange.location
        let style = index < (textView.string as NSString).length
            ? textView.textStorage?.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
            : textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        alignmentButton?.selectItem(at: Int(modelAlignment(style?.alignment ?? .natural).rawValue))
        updateFormattingWarning()
    }

    private func updateFormattingWarning() {
        guard let layout = textView.layoutManager, let storage = textView.textStorage else { return }
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
        var ranges: [NSRange] = []
        if !unitText.formattingWarningDismissed {
            storage.enumerateAttributes(in: whole, options: []) { attributes, range, _ in
                guard hasFormattingConflict(attributes) else { return }
                layout.addTemporaryAttribute(.backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.3), forCharacterRange: range)
                if let previous = ranges.last, NSMaxRange(previous) == range.location {
                    ranges[ranges.count - 1] = NSUnionRange(previous, range)
                } else { ranges.append(range) }
            }
        }
        if ranges != formattingConflictRanges { formattingConflictPopover?.close() }
        formattingConflictRanges = ranges
        layoutFormattingMarkers()
    }

    func layoutFormattingMarkers() {
        guard isViewLoaded, !loading, !layingOutFormattingMarkers,
              let layout = textView.layoutManager, let container = textView.textContainer else { return }
        layingOutFormattingMarkers = true
        defer { layingOutFormattingMarkers = false }
        layout.ensureLayout(for: container)
        var frames: [NSRect] = []
        var markedLines: Set<Int> = []
        let origin = textView.textContainerOrigin
        for range in formattingConflictRanges {
            guard range.length > 0, NSMaxRange(range) <= (textView.string as NSString).length else { continue }
            let glyph = layout.glyphIndexForCharacter(at: NSMaxRange(range) - 1)
            var lineRange = NSRange()
            let line = layout.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: &lineRange)
            guard markedLines.insert(lineRange.location).inserted else { continue }
            var frame = NSRect(x: origin.x + line.maxX + 3, y: origin.y + line.midY - 10, width: 20, height: 20)
            frame.origin.x = min(frame.origin.x, textView.bounds.maxX - 22)
            frames.append(frame)
        }
        while formattingMarkers.count > frames.count {
            formattingConflictPopover?.close()
            formattingMarkers.removeLast().view.removeFromSuperview()
        }
        while formattingMarkers.count < frames.count {
            guard let marker = editorStoryboard().instantiateController(withIdentifier: "FormattingConflictMarker")
                as? FormattingWarningViewController else { preconditionFailure("Missing formatting marker") }
            marker.editor = self
            _ = marker.view
            marker.markerButton.contentTintColor = .systemOrange
            marker.markerButton.setAccessibilityLabel(writeString("formatting.conflict.accessibility-label",
                "Formatting conflict", "Accessibility name of the inline warning marker."))
            marker.markerButton.setAccessibilityHelp(writeString("formatting.conflict.accessibility-help",
                "Bold or Italic overlaps semantic emphasis. Show conversion and dismissal options.",
                "Accessibility help for the formatting conflict marker; Bold and Italic are appearance choices."))
            marker.markerButton.identifier = NSUserInterfaceItemIdentifier("formattingConflictMarker")
            textView.addSubview(marker.view)
            formattingMarkers.append(marker)
        }
        for (marker, frame) in zip(formattingMarkers, frames) { marker.view.frame = frame }
    }

    func showInlineFormattingWarning(_ sender: NSButton) {
        if formattingConflictPopover == nil {
            guard let content = editorStoryboard().instantiateController(withIdentifier: "FormattingConflict")
                as? FormattingWarningViewController else { preconditionFailure("Missing formatting warning") }
            content.editor = self
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = content
            formattingConflictPopover = popover
        }
        formattingConflictPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
}

extension EditorViewController {
    private func setFormattingWarningDismissed(_ dismissed: Bool) {
        let previous = unitText.formattingWarningDismissed
        guard previous != dismissed else { return }
        editingUndoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.setFormattingWarningDismissed(previous) }
        }
        let original = unitText
        work.replaceText(verifiedValue { try TextUnit(identifier: original.identifier, title: original.title,
            paragraphs: original.paragraphs, formattingWarningDismissed: dismissed) })
        updateFormattingWarning()
        textDidChange?()
    }

    @IBAction public func dismissFormattingWarning(_ sender: Any?) {
        formattingConflictPopover?.close()
        setFormattingWarningDismissed(true)
        editingUndoManager.setActionName(writeString("formatting.conflict.dismiss.undo", "Dismiss Formatting Warning",
            "Undo action name for dismissing a warning; AppKit adds Undo or Redo."))
    }

    @IBAction public func convertPresentationToEmphasis(_ sender: Any?) {
        formattingConflictPopover?.close()
        let convert: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
            guard hasFormattingConflict(attributes) else { return }
            let emphasis = modelEmphasis(attributes)
            let bold = (attributes[EditorAttribute.bold] as? NSNumber)?.boolValue == true || emphasisUsesBold(emphasis)
            let italic = (attributes[EditorAttribute.italic] as? NSNumber)?.boolValue == true || emphasisUsesItalic(emphasis)
            attributes[EditorAttribute.emphasis] = (bold && italic ? TextEmphasis.veryStrongEmphasis
                : (bold ? .strongEmphasis : .emphasis)).rawValue
            attributes[EditorAttribute.bold] = false
            attributes[EditorAttribute.italic] = false
            renderAttributes(&attributes)
        }
        let name = writeString("formatting.convert-to-emphasis.undo", "Convert Presentation to Emphasis",
            "Undo action name for converting visual Bold or Italic into semantic emphasis.")
        editingUndoManager.beginUndoGrouping()
        editAttributes(in: NSRange(location: 0, length: (textView.string as NSString).length), name: name, transform: convert)
        if textView.selectedRange.length == 0 && hasFormattingConflict(textView.typingAttributes) {
            var after = textView.typingAttributes
            convert(&after)
            applyTypingFormatting(after)
        }
        setFormattingWarningDismissed(true)
        editingUndoManager.setActionName(name)
        editingUndoManager.endUndoGrouping()
        updateFormattingControls()
    }

    private func applyTypingFormatting(_ attributes: [NSAttributedString.Key: Any]) {
        let previous = textView.typingAttributes
        editingUndoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.applyTypingFormatting(previous) }
        }
        textView.typingAttributes = attributes
        updateFormattingControls()
    }

    public func textViewDidChangeSelection(_ notification: Notification) { updateFormattingControls() }
    public func textViewDidChangeTypingAttributes(_ notification: Notification) { updateFormattingControls() }

    @IBAction public func toggleEmphasis(_ sender: Any?) {
        toggle(EditorAttribute.emphasis, value: TextEmphasis.emphasis.rawValue,
            name: writeString("formatting.emphasis.undo", "Emphasis",
                "Undo action name for applying semantic emphasis, distinct from visual Italic. AppKit adds Undo or Redo."))
    }
    @IBAction public func toggleStrongEmphasis(_ sender: Any?) {
        toggle(EditorAttribute.emphasis, value: TextEmphasis.strongEmphasis.rawValue,
            name: writeString("formatting.strong-emphasis.undo", "Strong Emphasis",
                "Undo action name for applying strong semantic emphasis, distinct from visual Bold. AppKit adds Undo or Redo."))
    }
    @IBAction public func toggleVeryStrongEmphasis(_ sender: Any?) {
        toggle(EditorAttribute.emphasis, value: TextEmphasis.veryStrongEmphasis.rawValue,
            name: writeString("formatting.very-strong-emphasis", "Very Strong Emphasis",
                "Undo action name for the strongest semantic emphasis level."))
    }
    @IBAction public func toggleBold(_ sender: Any?) {
        toggle(EditorAttribute.bold, value: 1, name: writeString("formatting.bold", "Bold",
            "Undo action name for visual bold formatting, distinct from semantic Strong Emphasis."))
    }
    @IBAction public func toggleItalic(_ sender: Any?) {
        toggle(EditorAttribute.italic, value: 1, name: writeString("formatting.italic", "Italic",
            "Undo action name for visual italic formatting, distinct from semantic Emphasis."))
    }
    @IBAction public func toggleUnderline(_ sender: Any?) {
        toggle(EditorAttribute.underline, value: 1, name: writeString("formatting.underline", "Underline",
            "Undo action name for visual underline formatting."))
    }
    @IBAction public func toggleStrikethrough(_ sender: Any?) {
        toggle(EditorAttribute.strikethrough, value: 1, name: writeString("formatting.strikethrough", "Strikethrough",
            "Undo action name for visual strikethrough formatting."))
    }

    @IBAction func showAppearance(_ sender: NSButton) {
        if appearancePopover?.isShown == true { appearancePopover?.performClose(sender); return }
        if appearancePopover == nil {
            guard let content = editorStoryboard().instantiateController(withIdentifier: "Appearance")
                as? AppearanceViewController else { preconditionFailure("Missing Appearance storyboard controller") }
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
        if NSEvent.modifierFlags.contains(.option) { toggleItalic(sender) } else { toggleEmphasis(sender) }
    }
    @IBAction func chooseStrongEmphasis(_ sender: NSButton) {
        if NSEvent.modifierFlags.contains(.option) { toggleBold(sender) } else { toggleStrongEmphasis(sender) }
    }
    @IBAction func showFormattingHelp(_ sender: NSButton) {
        if formattingHelp == nil {
            guard let content = editorStoryboard().instantiateController(withIdentifier: "FormattingHelp")
                as? NSViewController else { preconditionFailure("Missing Formatting Help storyboard controller") }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = content
            formattingHelp = popover
        }
        formattingHelp?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    private func toggle(_ key: NSAttributedString.Key, value: UInt, name: String) {
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
        } else { editAttributes(in: textView.selectedRange, name: name, transform: change) }
    }

    @IBAction public func clearFormatting(_ sender: Any?) {
        let clear: (inout [NSAttributedString.Key: Any]) -> Void = { attributes in
            attributes[EditorAttribute.emphasis] = TextEmphasis.none.rawValue
            for key in [EditorAttribute.bold, EditorAttribute.italic,
                        EditorAttribute.underline, EditorAttribute.strikethrough] { attributes[key] = false }
            renderAttributes(&attributes)
        }
        if textView.selectedRange.length == 0 {
            var attributes = textView.typingAttributes
            clear(&attributes)
            textView.typingAttributes = attributes
            updateFormattingControls()
            if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
        } else {
            editAttributes(in: textView.selectedRange, name: writeString("formatting.clear.undo", "Clear Formatting",
                "Undo action name for removing character formatting."), transform: clear)
        }
    }

    private func editAttributes(in range: NSRange, name: String,
                                transform: (inout [NSAttributedString.Key: Any]) -> Void) {
        guard range.length > 0, let storage = textView.textStorage else { return }
        let selection = textView.selectedRange
        let before = storage.attributedSubstring(from: range)
        let after = NSMutableAttributedString(attributedString: before)
        before.enumerateAttributes(in: NSRange(location: 0, length: before.length), options: []) { attributes, subrange, _ in
            var changed = attributes
            transform(&changed)
            after.setAttributes(changed, range: subrange)
        }
        textView.breakUndoCoalescing()
        applyFormatting(after, range: range, actionName: name)
        textView.setSelectedRange(selection)
        if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
    }

    private func applyFormatting(_ text: NSAttributedString, range: NSRange, actionName: String) {
        guard let storage = textView.textStorage else { return }
        let previous = storage.attributedSubstring(from: range)
        editingUndoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.applyFormatting(previous, range: range, actionName: actionName) }
        }
        storage.beginEditing()
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, part, _ in
            storage.setAttributes(attributes, range: NSRange(location: range.location + part.location, length: part.length))
        }
        storage.endEditing()
        textView.didChangeText()
        editingUndoManager.setActionName(actionName)
    }

    private func applyEmptyParagraphAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        let previous = textView.typingAttributes
        editingUndoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.applyEmptyParagraphAttributes(previous) }
        }
        textView.typingAttributes = attributes
        textView.didChangeText()
        editingUndoManager.setActionName(writeString("paragraph.alignment.undo", "Paragraph Alignment",
            "Undo action name for changing paragraph alignment."))
    }

    @IBAction func changeParagraphAlignment(_ sender: NSPopUpButton) {
        let alignment = nativeAlignment(ParagraphAlignment(rawValue: UInt(sender.indexOfSelectedItem)) ?? .natural)
        let range = (textView.string as NSString).paragraphRange(for: textView.selectedRange)
        if range.length == 0 {
            var attributes = textView.typingAttributes
            let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            style.alignment = alignment
            attributes[.paragraphStyle] = style
            applyEmptyParagraphAttributes(attributes)
        } else {
            editAttributes(in: range, name: writeString("paragraph.alignment.undo", "Paragraph Alignment",
                "Undo action name for changing paragraph alignment.")) { attributes in
                let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
                style.alignment = alignment
                attributes[.paragraphStyle] = style
            }
        }
        if appearancePopover?.isShown != true { view.window?.makeFirstResponder(textView) }
    }
}

/// Storyboard window chrome routes toolbar commands to the active Content Unit.
@MainActor @objc(FWEditorWindowController) final class EditorWindowController: NSWindowController {
    @IBOutlet var emphasisButton: NSButton!
    @IBOutlet var strongButton: NSButton!
    @IBOutlet var clearButton: NSButton!
    @IBOutlet var helpButton: NSButton!
    @IBOutlet var alignmentButton: NSPopUpButton!

    private var formattingEditor: EditorViewController? {
        if let manuscript = contentViewController as? ManuscriptViewController { return manuscript.activeEditor }
        return contentViewController as? EditorViewController
    }
    @IBAction func showAppearance(_ sender: NSButton) { formattingEditor?.showAppearance(sender) }
    @IBAction func chooseEmphasis(_ sender: NSButton) { formattingEditor?.chooseEmphasis(sender) }
    @IBAction func chooseStrongEmphasis(_ sender: NSButton) { formattingEditor?.chooseStrongEmphasis(sender) }
    @IBAction func clearFormatting(_ sender: Any?) { formattingEditor?.clearFormatting(sender) }
    @IBAction func changeParagraphAlignment(_ sender: NSPopUpButton) { formattingEditor?.changeParagraphAlignment(sender) }
    @IBAction func showFormattingHelp(_ sender: NSButton) { formattingEditor?.showFormattingHelp(sender) }
}

@MainActor @objc(FWAppearanceViewController) final class AppearanceViewController: NSViewController {
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

@MainActor @objc(FWFormattingWarningViewController) final class FormattingWarningViewController: NSViewController {
    weak var editor: EditorViewController?
    @IBOutlet var markerButton: NSButton!
    @IBAction func showWarning(_ sender: NSButton) { editor?.showInlineFormattingWarning(sender) }
    @IBAction func convertPresentationToEmphasis(_ sender: Any?) { editor?.convertPresentationToEmphasis(sender) }
    @IBAction func dismissFormattingWarning(_ sender: Any?) { editor?.dismissFormattingWarning(sender) }
}
