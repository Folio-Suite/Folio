// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

/// The storyboard text surface keeps native input, selection, and Undo behavior.
@MainActor @objc(FWTextView) final class EditorTextView: NSTextView {
    weak var editor: EditorViewController?

    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() ?? []
        for view in subviews {
            for child in NSAccessibility.unignoredChildren(from: [view]) {
                if !children.contains(where: { ($0 as AnyObject) === (child as AnyObject) }) { children.append(child) }
            }
        }
        return children
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        editor?.layoutFormattingMarkers()
    }

    @IBAction func toggleEmphasis(_ sender: Any?) { editor?.toggleEmphasis(sender) }
    @IBAction func toggleStrongEmphasis(_ sender: Any?) { editor?.toggleStrongEmphasis(sender) }
    @IBAction func toggleVeryStrongEmphasis(_ sender: Any?) { editor?.toggleVeryStrongEmphasis(sender) }
    @IBAction func toggleBold(_ sender: Any?) { editor?.toggleBold(sender) }
    @IBAction func toggleItalic(_ sender: Any?) { editor?.toggleItalic(sender) }
    @IBAction func toggleUnderline(_ sender: Any?) { editor?.toggleUnderline(sender) }
    @IBAction func toggleStrikethrough(_ sender: Any?) { editor?.toggleStrikethrough(sender) }
    @IBAction func clearFormatting(_ sender: Any?) { editor?.clearFormatting(sender) }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [EditorAttribute.pasteboardType, .string]
    }

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [EditorAttribute.pasteboardType, .string]
    }

    override func writeSelection(to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == EditorAttribute.pasteboardType else { return super.writeSelection(to: pasteboard, type: type) }
        guard let storage = textStorage, selectedRange.length > 0 else { return false }
        var runs: [[String: Any]] = []
        storage.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
            let style = attributes[.paragraphStyle] as? NSParagraphStyle
            runs.append(["text": (string as NSString).substring(with: range),
                         "emphasis": (attributes[EditorAttribute.emphasis] as? NSNumber) ?? 0,
                         "bold": (attributes[EditorAttribute.bold] as? NSNumber) ?? false,
                         "italic": (attributes[EditorAttribute.italic] as? NSNumber) ?? false,
                         "underline": (attributes[EditorAttribute.underline] as? NSNumber) ?? false,
                         "strikethrough": (attributes[EditorAttribute.strikethrough] as? NSNumber) ?? false,
                         "alignment": modelAlignment(style?.alignment ?? .natural).rawValue])
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: runs, format: .binary, options: 0) else {
            return false
        }
        return pasteboard.setData(data, forType: type)
    }

    override func readSelection(from pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == EditorAttribute.pasteboardType else { return super.readSelection(from: pasteboard, type: type) }
        guard let data = pasteboard.data(forType: type),
              let decoded = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let runs = decoded as? [[String: Any]] else { return false }
        let inserted = NSMutableAttributedString(string: "")
        for run in runs {
            guard let string = run["text"] as? String,
                  let emphasisNumber = run["emphasis"] as? NSNumber,
                  let alignmentNumber = run["alignment"] as? NSNumber,
                  emphasisNumber.doubleValue == Double(emphasisNumber.uintValue),
                  alignmentNumber.doubleValue == Double(alignmentNumber.uintValue),
                  let emphasis = TextEmphasis(rawValue: emphasisNumber.uintValue),
                  let alignment = ParagraphAlignment(rawValue: alignmentNumber.uintValue),
                  let bold = run["bold"] as? NSNumber, (bold == 0 || bold == 1),
                  let italic = run["italic"] as? NSNumber, (italic == 0 || italic == 1),
                  let underline = run["underline"] as? NSNumber, (underline == 0 || underline == 1),
                  let strikethrough = run["strikethrough"] as? NSNumber, (strikethrough == 0 || strikethrough == 1) else {
                return false
            }
            let presentation = TextPresentation(bold: bold.boolValue, italic: italic.boolValue,
                underline: underline.boolValue, strikethrough: strikethrough.boolValue)
            inserted.append(NSAttributedString(string: string,
                attributes: editorAttributes(emphasis: emphasis, presentation: presentation, alignment: alignment)))
        }
        insertText(inserted, replacementRange: selectedRange)
        return true
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let inserted: NSMutableAttributedString
        if let attributed = insertString as? NSAttributedString {
            inserted = NSMutableAttributedString(attributedString: attributed)
        } else {
            inserted = NSMutableAttributedString(string: String(describing: insertString), attributes: typingAttributes)
        }
        for separator in ["\r\n", "\r", "\u{2029}"] {
            while true {
                let range = (inserted.string as NSString).range(of: separator)
                guard range.location != NSNotFound else { break }
                inserted.replaceCharacters(in: range, with: "\n")
            }
        }
        let insertion = replacementRange.location == NSNotFound ? selectedRange.location : replacementRange.location
        let source = string as NSString
        if insertion <= source.length, let editor {
            let paragraphIndex = source.substring(to: insertion).components(separatedBy: "\n").count - 1
            let paragraphs = editor.unitText.paragraphs
            if paragraphIndex < paragraphs.count, inserted.length > 0 {
                inserted.addAttribute(EditorAttribute.paragraphIdentity,
                    value: paragraphs[paragraphIndex].identifier.rawValue,
                    range: NSRange(location: 0, length: inserted.length))
            }
        }
        super.insertText(inserted, replacementRange: replacementRange)
    }
}
