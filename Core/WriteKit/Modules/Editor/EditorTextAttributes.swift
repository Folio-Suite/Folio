// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import FolioKit

enum EditorAttribute {
  static let emphasis = NSAttributedString.Key("FolioTextEmphasis")
  static let bold = NSAttributedString.Key("FolioTextBold")
  static let italic = NSAttributedString.Key("FolioTextItalic")
  static let underline = NSAttributedString.Key("FolioTextUnderline")
  static let strikethrough = NSAttributedString.Key("FolioTextStrikethrough")
  static let paragraphIdentity = NSAttributedString.Key("FolioParagraphIdentity")
  static let pasteboardType = NSPasteboard.PasteboardType("dev.foliosuite.text-fragment-v2")
}

func nativeAlignment(_ alignment: ParagraphAlignment) -> NSTextAlignment {
  switch alignment {
  case .natural: .natural
  case .left: .left
  case .center: .center
  case .right: .right
  case .justified: .justified
  }
}

func modelAlignment(_ alignment: NSTextAlignment) -> ParagraphAlignment {
  switch alignment {
  case .left: .left
  case .center: .center
  case .right: .right
  case .justified: .justified
  default: .natural
  }
}

func emphasisUsesBold(_ emphasis: TextEmphasis) -> Bool {
  emphasis == .strongEmphasis || emphasis == .veryStrongEmphasis
}

func emphasisUsesItalic(_ emphasis: TextEmphasis) -> Bool {
  emphasis == .emphasis || emphasis == .veryStrongEmphasis
}

func modelPresentation(_ attributes: [NSAttributedString.Key: Any]) -> TextPresentation {
  TextPresentation(
    bold: (attributes[EditorAttribute.bold] as? NSNumber)?.boolValue ?? false,
    italic: (attributes[EditorAttribute.italic] as? NSNumber)?.boolValue ?? false,
    underline: (attributes[EditorAttribute.underline] as? NSNumber)?.boolValue ?? false,
    strikethrough: (attributes[EditorAttribute.strikethrough] as? NSNumber)?.boolValue ?? false)
}

func modelEmphasis(_ attributes: [NSAttributedString.Key: Any]) -> TextEmphasis {
  TextEmphasis(rawValue: (attributes[EditorAttribute.emphasis] as? NSNumber)?.uintValue ?? 0)
    ?? .none
}

@MainActor func renderAttributes(_ attributes: inout [NSAttributedString.Key: Any]) {
  let emphasis = modelEmphasis(attributes)
  let base = NSFont(name: "Times New Roman", size: 18) ?? .systemFont(ofSize: 18)
  var traits: NSFontTraitMask = []
  if (attributes[EditorAttribute.bold] as? NSNumber)?.boolValue == true
    || emphasisUsesBold(emphasis) {
    traits.insert(.boldFontMask)
  }
  if (attributes[EditorAttribute.italic] as? NSNumber)?.boolValue == true
    || emphasisUsesItalic(emphasis) {
    traits.insert(.italicFontMask)
  }
  attributes[.font] = NSFontManager.shared.convert(base, toHaveTrait: traits)
  attributes[.underlineStyle] =
    (attributes[EditorAttribute.underline] as? NSNumber)?.boolValue == true
    ? NSUnderlineStyle.single.rawValue : 0
  attributes[.strikethroughStyle] =
    (attributes[EditorAttribute.strikethrough] as? NSNumber)?.boolValue == true
    ? NSUnderlineStyle.single.rawValue : 0
}

@MainActor func editorAttributes(
  emphasis: TextEmphasis, presentation: TextPresentation,
  alignment: ParagraphAlignment
) -> [NSAttributedString.Key: Any] {
  let style = NSMutableParagraphStyle()
  style.alignment = nativeAlignment(alignment)
  style.paragraphSpacing = 10
  var attributes: [NSAttributedString.Key: Any] = [
    EditorAttribute.emphasis: emphasis.rawValue,
    EditorAttribute.bold: presentation.bold,
    EditorAttribute.italic: presentation.italic,
    EditorAttribute.underline: presentation.underline,
    EditorAttribute.strikethrough: presentation.strikethrough,
    .foregroundColor: NSColor.textColor,
    .paragraphStyle: style,
  ]
  renderAttributes(&attributes)
  return attributes
}

func hasFormattingConflict(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
  modelEmphasis(attributes) != .none
    && ((attributes[EditorAttribute.bold] as? NSNumber)?.boolValue == true
      || (attributes[EditorAttribute.italic] as? NSNumber)?.boolValue == true)
}
