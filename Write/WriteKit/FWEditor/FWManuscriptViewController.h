// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <AppKit/AppKit.h>
@class FWWork, FWEditorViewController;
NS_ASSUME_NONNULL_BEGIN

/// A storyboard-defined Manuscript sidebar and its retained per-unit editors.
/// Main-thread only. The host owns document saving and the shared undo manager.
/// Selection is transient; titles, order, text, and warning preferences belong to the Work.
@interface FWManuscriptViewController : NSViewController
/// Replacing the Work resets editors and selection. The host must first clear undo history.
@property (nonatomic, strong) FWWork *work;
/// The selected unit's editor, available once the view loads.
@property (nonatomic, strong, readonly) FWEditorViewController *activeEditor;
/// Stable identity of the selected unit; nil until the view loads.
@property (nonatomic, copy, readonly, nullable) NSString *selectedUnitIdentifier;
/// Synchronous notification of an authored change, including structural edits.
/// The host should ignore this for change counting while undoing or redoing.
@property (nonatomic, copy, nullable) void (^workDidChange)(void);
/// Retains the Work and document undo manager. All edits share chronological undo.
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager;
/// Creates the native document window and connects its formatting toolbar. Call once.
- (NSWindowController *)makeWindowController;
/// Selects an existing unit without adding an undo action or changing the Work.
- (void)selectUnitWithIdentifier:(NSString *)identifier;
/// Appends and selects an empty titled Content Unit. Undo removes that addition.
- (IBAction)addContentUnit:(nullable id)sender;
/// Renames the selected unit from the storyboard title field; blank titles become Untitled.
- (IBAction)renameContentUnit:(nullable id)sender;
/// Moves the selected unit one position earlier; no-op at the beginning.
- (IBAction)moveContentUnitUp:(nullable id)sender;
/// Moves the selected unit one position later; no-op at the end.
- (IBAction)moveContentUnitDown:(nullable id)sender;
@end
NS_ASSUME_NONNULL_END
