// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit

/// Semantic formatting symbols owned by WriteKit for its editor and host menus.
/// Request them on the main actor after loading the framework. Returned NSImage
/// objects belong to the bundle's resource lookup; copy before customizing them.
/// A missing bundled asset is a packaging invariant failure.
@MainActor
public enum FormattingImages {
  /// The bundled E symbol for semantic Emphasis, distinct from an Italic command.
  public static var emphasis: NSImage { image(named: "Emphasis") }

  /// The bundled E symbol for semantic Strong Emphasis, distinct from a Bold command.
  public static var strongEmphasis: NSImage { image(named: "StrongEmphasis") }

  private static func image(named name: String) -> NSImage {
    guard let image = writeKitBundle.image(forResource: NSImage.Name(name)) else {
      preconditionFailure("WriteKit formatting image \(name) is missing")
    }
    return image
  }
}
