<!--
SPDX-FileCopyrightText: 2025 Charles Wiltgen
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# NSTextView and TextKit

## Identify the actual text system

Inspect the storyboard/nib configuration and the text network built by the owning editor. Query `NSTextView.textLayoutManager` before touching `layoutManager`: accessing the legacy layout manager on a compatible TextKit 2 view can trigger a switch to TextKit 1. `NSTextViewWillSwitchToNSLayoutManagerNotification` can help locate an unexpected switch. Do not diagnose the system by accessing the property that changes it.

For an intentionally programmatic text view, `initUsingTextLayoutManager:` selects the text network. For Folio's storyboard-backed editors, preserve the existing scene, connections, and resource ownership. Determine whether the task needs a migration at all; existing TextKit 1 dependencies may be intentional. If migrating, inventory glyph APIs, text tables, custom layout, attachments, selection, printing, and undo first, then verify each required behavior.

Primary references: [NSTextView](https://developer.apple.com/documentation/appkit/nstextview), [AppKit TextKit](https://developer.apple.com/documentation/appkit/textkit).

## Choose the appropriate layer

In TextKit 2, content managers provide text elements, `NSTextLayoutManager` produces layout fragments, and `NSTextViewportLayoutController` coordinates the visible region. Prefer the existing NSTextView for input, selection, accessibility, and undo; taking over layout or rendering also creates integration obligations for those behaviors.

Use text ranges and fragment geometry for TextKit 2 layout questions instead of mechanically translating glyph-index algorithms. Layout is noncontiguous: offscreen fragments may not be laid out. Request the extent actually needed and measure the effect of forcing whole-document layout on a long Work. Visible-fragment measurements alone are not a whole-document line count or pagination result.

Primary references: [NSTextLayoutManager](https://developer.apple.com/documentation/appkit/nstextlayoutmanager), [NSTextViewportLayoutController](https://developer.apple.com/documentation/appkit/nstextviewportlayoutcontroller).

## Preserve ranges and editing semantics

For NSString-backed text storage, `NSRange` counts UTF-16 code units, not user-perceived characters. Convert to and from TextKit 2 locations through the content manager that owns those locations, validate bounds and missing locations, and account for mutations before reusing ranges. Custom content managers may not have a linear NSString mapping. Exercise composed characters, emoji, combining marks, bidirectional text, and discontiguous selections when the feature touches indexing or navigation.

Route user editing through the existing editor/domain command path so selection, change notifications, document dirty state, and undo remain coordinated. If directly implementing an NSTextView text change, respect `shouldChangeTextInRange:replacementString:` (or the multiple-range variant) and `didChangeText`; account separately for the established undo and domain synchronization. A TextKit content-manager editing transaction batches text-system edits; it is not automatically a domain transaction or an NSUndoManager group.

Keep transient selection, spelling, and presentation decoration separate from authored formatting in the model. Preserve marked text during input-method composition; avoid replacing the entire editor string on every model notification. Verify typing, replacement, paste, undo/redo, and save/reopen for an edit-path change.

Primary references: [NSTextView editing](https://developer.apple.com/documentation/appkit/nstextview), [NSTextContentManager](https://developer.apple.com/documentation/appkit/nstextcontentmanager).

## Writing Tools and other system editing

Use the actual AppKit NSTextView delegate contracts and availability for the selected SDK; UIKit delegate examples are not interchangeable. Define how system-proposed replacements enter the same domain and undo path as other edits, how protected ranges are handled, and how selection or temporary presentation changes are distinguished from accepted authored content. Preserve normal save/recovery behavior while system editing is active.

Verify the real interaction before claiming support, including cancellation and undo. A source-level property setting does not establish that system rewriting preserves Folio's semantic attributes or document history.

Primary reference: [NSTextViewDelegate](https://developer.apple.com/documentation/appkit/nstextviewdelegate).
