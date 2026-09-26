<!--
SPDX-FileCopyrightText: 2025 Charles Wiltgen
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# AppKit interaction

## Commands and input

Trace the responder chain and the actual target of a command before changing event handling. Use native target/action, menu validation, and the owning controller's command path so menu items, toolbar items, and keyboard equivalents agree. For document-specific commands, exercise two open windows with different selections; confirm that the active document receives the command and inactive state does not determine enablement.

Inspect storyboard action/outlet connections and selectors together. Preserve stable scene and localization identifiers. A command enabled in a menu still needs appropriate validation at its execution boundary when it can also be invoked elsewhere.

For built-in table/outline selection, context menus, and dragging, first use the control's selection/delegate, menu, and pasteboard APIs. Retain custom event handling when it provides behavior those APIs do not cover; the existence of `mouseDown:` is not itself a defect. When clicks fail, inspect overlapping views and hit testing. A wholly decorative overlay may pass events through; an overlay with interactive children needs selective hit testing.

Primary references: [NSResponder](https://developer.apple.com/documentation/appkit/nsresponder), [NSMenuItemValidation](https://developer.apple.com/documentation/appkit/nsmenuitemvalidation), [NSView](https://developer.apple.com/documentation/appkit/nsview).

## Keyboard focus

Check the window's first responder, initial first responder, controls' eligibility for keyboard focus, and key-view loop. Use `autorecalculatesKeyViewLoop` when automatic ordering matches the interface; maintain explicit ordering when the interaction needs it. Avoid overwriting intentional focus during view loading or model refresh.

Verify Tab and Shift-Tab through visible controls, activation from the keyboard, Escape/dismissal, and focus return after sheets or popovers. Repeat after views appear, disappear, or become disabled. Judge reading and focus order against the layout direction and task, including right-to-left interfaces. For long-form text, verify standard text navigation as well as control-to-control movement.

Primary reference: [NSWindow](https://developer.apple.com/documentation/appkit/nswindow).

## Restoration and termination

Separate UI restoration from authoritative document persistence. Restore window identity, selection, and presentation using stable identifiers; reopen document content through its existing NSDocument/NSPersistentDocument and Kit lifecycle. Restoration archives are not an additional database. Treat restored identifiers as potentially stale and recover when content has moved or been deleted.

For custom restorable windows, inspect identifiers, restoration ownership, invalidation of changed state, and the restoration completion handler. Ensure every completion path returns a window or an error. Preserve superclass restoration behavior. Use the document framework's existing restoration path for document windows before adding a parallel restoration controller.

Preserve unsaved-edit and failed-save handling during close or quit. If adjusting a modal window's termination behavior, distinguish informational UI from a sheet that must resolve data loss or a failed operation. Verify cancellation, successful save, failed save, and relaunch for the path being changed.

Primary references: [NSWindowRestoration](https://developer.apple.com/documentation/appkit/nswindowrestoration), [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument).

## New SDK APIs

The selected Axiom source includes macOS 27 input, status-item, and appearance APIs. Look up their exact AppKit selectors and availability only when the task needs them. Keep the existing deployment minimum and older-system behavior intact unless the user explicitly changes that requirement. Validate both the new path and its fallback; compiling with the newest SDK only validates the first part.
