// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Semantic formatting symbols owned by WriteKit for its editor and host menus.
@MainActor
public enum FormattingImages {
  /// The symbol for Emphasis.
  public static var emphasis: NSImage { image(named: "Emphasis") }

  /// The symbol for Strong Emphasis.
  public static var strongEmphasis: NSImage { image(named: "StrongEmphasis") }

  private static func image(named name: String) -> NSImage {
    guard let image = writeKitBundle.image(forResource: NSImage.Name(name)) else {
      preconditionFailure("WriteKit formatting image \(name) is missing")
    }
    return image
  }
}
