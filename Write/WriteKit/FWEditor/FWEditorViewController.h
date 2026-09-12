// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <AppKit/AppKit.h>
@class FWWork;

NS_ASSUME_NONNULL_BEGIN

/// A native editor bound to one text Content Unit in a Work.
///
/// Create the controller with a Work and its document's undo manager, then call
/// ``makeWindowController`` for a native window and formatting toolbar. The bundled
/// Editor storyboard defines the window, toolbar, text surface, and help content;
/// appearing in a window focuses the text surface.
/// All access must occur on the main thread. The controller owns presentation,
/// selection, and editing integration; the host owns saving and document lifecycle.
///
/// Semantic emphasis and explicit bold/italic remain independent even when they
/// look alike. Formatting controls show on, off, or mixed selection states.
/// The primary italic-E and bold-E buttons apply semantic formatting; Option-click applies
/// explicit italic or bold. Help is available in a popover and control tooltips.
/// Semantic/presentation conflicts receive temporary yellow highlights and inline
/// warning buttons that open conversion and dismissal choices. These diagnostics
/// never become authored text; dismissal is remembered for the Content Unit.
/// Internal paste preserves supported formatting with independent content identity;
/// external paste accepts plain text. This editor does not implement shared Work
/// Session authority or durable acceptance of each edit.
@interface FWEditorViewController : NSViewController
/// The Work being edited, retained by the controller.
///
/// Assigning a Work to a loaded editor replaces displayed text and resets selection
/// to the beginning. The host must resolve pending edits and manage undo history
/// when replacing a Work. Mutating its text externally does not refresh this view;
/// assign the Work again to display a replacement snapshot.
@property (nonatomic, strong) FWWork *work;
/// The native text surface, available after the controller's view has loaded.
///
/// Use native editing actions to keep semantic state and undo synchronized.
/// Direct text-storage mutations bypass this contract. The editor owns the text
/// view's delegate; callers must not replace it.
@property (nonatomic, strong, readonly) NSTextView *textView;
/// Optional synchronous notification that an editing change has been captured.
///
/// Invoked on the main thread after the Work's text is updated. A host may use
/// this to update document edited state. Undo and redo can also produce editing
/// notifications; the host should consult its undo manager when counting changes.
/// This callback is not a save acknowledgment. Use a weak host reference in the
/// block to avoid a retain cycle through the controller.
@property (nonatomic, copy, nullable) void (^textDidChange)(void);
/// Creates an editor that retains the supplied Work and undo manager.
///
/// - Parameters:
///   - work: The Work whose supported text is displayed and edited.
///   - undoManager: The host's undo manager, shared with native text editing and
///     custom formatting. Use a separate manager for each independent Work.
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager;
/// Binds an editor to an existing unit. Its identity remains fixed when Manuscript order changes.
/// Use the same document undo manager for all editors; retain each editor while its undo history exists.
- (instancetype)initWithWork:(FWWork *)work contentUnitIdentifier:(NSString *)identifier undoManager:(NSUndoManager *)undoManager;
/// Notification after native undo changes this editor's text, for revealing its unit.
/// Called on the main thread; does not represent a new edit or save acknowledgment.
@property (nonatomic, copy, nullable) void (^undoDidChangeText)(void);
/// Creates a storyboard-defined document window with a native formatting toolbar.
///
/// Call once per editor, on the main thread. The returned controller hosts this
/// editor and routes toolbar actions to it. Retain it through the host document’s
/// window-controller collection; the host continues to own saving and edited state.
/// Embedding the editor's view directly supplies the text surface without a toolbar.
- (NSWindowController *)makeWindowController;
/// Toggles semantic emphasis for the selection, or for subsequent typing.
///
/// A mixed selection becomes uniformly emphasized, replacing other emphasis categories. Selected-text changes are
/// undoable; insertion-point changes affect typing attributes without saving text.
/// - Parameter sender: The initiating control, or nil for a programmatic action.
- (void)toggleEmphasis:(nullable id)sender;
/// Toggles semantic strong emphasis, with the selection rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleStrongEmphasis:(nullable id)sender;
/// Toggles the exclusive Very Strong Emphasis category (bold-italic in this editor).
/// Preserves presentation and follows the selection and undo rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleVeryStrongEmphasis:(nullable id)sender;
/// Converts conflicting Bold/Italic presentation throughout the current Content Unit
/// into semantic emphasis, preserving effective font traits, underline, and strikethrough.
/// The conversion and persistent warning dismissal form one undoable edit.
/// - Parameter sender: The initiating control, or nil.
- (IBAction)convertPresentationToEmphasis:(nullable id)sender;
/// Dismisses conflict highlights and inline warning buttons for this Content Unit across save/reopen.
/// This undoable metadata edit does not alter text or presentation.
/// - Parameter sender: The initiating control, or nil.
- (IBAction)dismissFormattingWarning:(nullable id)sender;
/// Toggles explicit bold independently of semantic strong emphasis.
///
/// Uses the selection and undo rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleBold:(nullable id)sender;
/// Toggles explicit italic independently of semantic emphasis.
///
/// Uses the selection and undo rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleItalic:(nullable id)sender;
/// Toggles a visual underline, using the selection and undo rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleUnderline:(nullable id)sender;
/// Toggles visual strikethrough without deleting text or creating a Proposed Revision.
/// Uses the selection and undo rules of ``toggleEmphasis:``.
/// - Parameter sender: The initiating control, or nil.
- (void)toggleStrikethrough:(nullable id)sender;
/// Clears supported semantic and explicit character formatting, preserving alignment.
///
/// Applies to selected text with undo support, or to subsequent typing when the
/// selection is empty. Returns keyboard focus to the text surface unless the
/// Appearance popover is open.
/// - Parameter sender: The initiating control, or nil.
- (void)clearFormatting:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END
