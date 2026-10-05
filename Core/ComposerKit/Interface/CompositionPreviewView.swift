// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import TypographyKit

/// A storyboard-owned canvas. Drawing, diagnostics and source relationships share one result.
@MainActor
public final class CompositionPreviewView: NSView {
    @IBOutlet private weak var statusLabel: NSTextField?
    /// Most recent composition, or `nil` before the first input is supplied.
    public private(set) var result: CompositionResult?

    /// Composes input synchronously, refreshes accessible status, and schedules drawing.
    ///
    /// AppKit performs the eventual redraw; returning from this method does not mean
    /// pixels have already been displayed. Unsupported results remain visible as diagnostics.
    public func show(_ input: PublicationPreviewInput) {
        result = ComposerPreview.compose(input)
        updateStatus()
        needsDisplay = true
    }

    /// Configures accessibility when AppKit attaches or detaches this view from a window.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("compositionPreview")
        updateStatus()
    }

    private func updateStatus() {
        let bundle = Bundle(for: Self.self)
        let status: String
        switch result?.status {
        case .complete:
            status = NSLocalizedString("preview.complete",
                bundle: bundle, value: "Composition preview",
                comment: "Heading for a bounded preview that satisfies its requested line constraints.")
        case .unsupported:
            status = NSLocalizedString("preview.unsupported",
                bundle: bundle, value: "Preview incomplete: unsupported text or controls",
                comment: "Heading when the typography engine cannot support the requested input.")
        case .infeasible:
            status = NSLocalizedString("preview.infeasible",
                bundle: bundle, value: "Preview incomplete: line constraints cannot be satisfied",
                comment: "Heading when the selected breaks or available width cannot satisfy the publication input.")
        case nil:
            status = NSLocalizedString(
                "preview.empty",
                bundle: bundle,
                value: "No composition preview",
                comment: "Empty state of the reusable composition canvas."
            )
        @unknown default:
            status = NSLocalizedString("preview.unsupported",
                bundle: bundle, value: "Preview incomplete: unsupported text or controls",
                comment: "Heading when the typography engine cannot support the requested input.")
        }
        statusLabel?.stringValue = status
        statusLabel?.textColor = result?.status == .complete ? .labelColor : .systemOrange
        let detail = result?.originalText ?? ""
        setAccessibilityLabel(status)
        setAccessibilityValue(detail)
        toolTip = status
    }

    /// Draws the current result in AppKit’s active graphics context.
    ///
    /// AppKit calls this after invalidation; hosts should use ``show(_:)`` rather than
    /// invoke drawing directly. TypographyKit also changes the context’s text matrix,
    /// which Core Graphics does not include in its saved graphics state.
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()
        guard let result, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setFillColor(NSColor.textColor.cgColor)
        // This NSView uses the default unflipped (Y-up) coordinates. The result’s
        // origin is a baseline near the top; subsequent lines proceed down the page.
        result.draw(in: context, at: CGPoint(x: 24, y: bounds.height - 90))
        context.restoreGState()
    }
}
