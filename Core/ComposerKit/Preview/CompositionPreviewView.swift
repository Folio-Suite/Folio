// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import TypographyKit

/// A storyboard-owned canvas. Drawing, diagnostics and source relationships share one result.
@MainActor
public final class CompositionPreviewView: NSView {
    @IBOutlet private weak var statusLabel: NSTextField?
    public private(set) var result: CompositionResult?

    public func show(_ input: PublicationPreviewInput) {
        result = ComposerPreview.compose(input)
        updateStatus()
        needsDisplay = true
    }

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
            status = NSLocalizedString("preview.empty",
                bundle: bundle, value: "No composition preview", comment: "Empty state of the reusable composition canvas.")
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

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()
        guard let result, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setFillColor(NSColor.textColor.cgColor)
        result.draw(in: context, at: CGPoint(x: 24, y: bounds.height - 90))
        context.restoreGState()
    }
}
