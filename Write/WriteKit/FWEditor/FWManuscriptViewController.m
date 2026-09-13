// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWManuscriptViewController.h"
#import "../FWManuscript/FWWork.h"
#import "FWEditorViewController+Internal.h"
#import <FolioKit/FolioKit.h>

@interface FWManuscriptViewController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) IBOutlet NSTableView *unitTable;
@property (nonatomic, strong) IBOutlet NSTextField *unitTitle;
@property (nonatomic, strong) IBOutlet NSView *editorHost;
@property (nonatomic, strong) IBOutlet NSButton *addButton;
@property (nonatomic, strong) IBOutlet NSButton *moveUpButton;
@property (nonatomic, strong) IBOutlet NSButton *moveDownButton;
@property (nonatomic, strong) FWEditorViewController *activeEditor;
@property (nonatomic, copy) NSString *selectedUnitIdentifier;
@property (nonatomic, strong) NSUndoManager *documentUndoManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FWEditorViewController *> *editors;
@property (nonatomic, weak) NSWindowController *documentWindowController;
@property (nonatomic) BOOL updatingSelection;
@end

@implementation FWManuscriptViewController
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager {
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
    self = [storyboard instantiateControllerWithIdentifier:@"Manuscript"];
    self.work = work;
    self.documentUndoManager = undoManager;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.addButton.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"manuscript.add-content-unit", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Add Content Unit", @"Add a unit to the Manuscript. Accessibility label and undo action name; Content Unit is a Folio domain term.");
    self.moveUpButton.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"manuscript.move-content-unit-up", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Move Content Unit Up", @"Accessibility label: move the selected Content Unit earlier in the Manuscript.");
    self.moveDownButton.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"manuscript.move-content-unit-down", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Move Content Unit Down", @"Accessibility label: move the selected Content Unit later in the Manuscript.");
    self.unitTable.dataSource = self;
    self.unitTable.delegate = self;
    self.unitTable.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"manuscript.units.accessibility-label", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Manuscript units", @"Accessibility name of the table listing Content Units in reading order.");
    self.unitTable.identifier = @"manuscriptUnits";
    self.unitTitle.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"content-unit.title.accessibility-label", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Content Unit title", @"Accessibility name of the editable title field.");
    self.unitTitle.identifier = @"contentUnitTitle";
    [self selectUnitWithIdentifier:self.work.text.identifier];
}
- (void)setWork:(FWWork *)work {
    _work = work;
    [self.activeEditor.view removeFromSuperview];
    for (NSViewController *editor in self.childViewControllers.copy) [editor removeFromParentViewController];
    self.editors = [NSMutableDictionary dictionary];
    self.activeEditor = nil;
    self.selectedUnitIdentifier = nil;
    if (self.isViewLoaded) [self selectUnitWithIdentifier:work.text.identifier];
}
- (NSWindowController *)makeWindowController {
    (void)self.view;
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
    NSWindowController *window = [storyboard instantiateControllerWithIdentifier:@"EditorWindow"];
    self.documentWindowController = window;
    window.contentViewController = self;
    [self selectUnitWithIdentifier:self.selectedUnitIdentifier];
    return window;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.work.manuscript.units.count; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    return self.work.manuscript.units[row].title;
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (self.updatingSelection || self.unitTable.selectedRow < 0) return;
    [self selectUnitWithIdentifier:self.work.manuscript.units[self.unitTable.selectedRow].identifier];
}
- (void)selectUnitWithIdentifier:(NSString *)identifier {
    FKText *unit = [self.work textWithIdentifier:identifier];
    if (!unit) return;
    (void)self.view;
    [self.activeEditor.textView breakUndoCoalescing];
    [self.activeEditor.view removeFromSuperview];
    FWEditorViewController *editor = self.editors[identifier];
    if (!editor) {
        editor = [[FWEditorViewController alloc] initWithWork:self.work contentUnitIdentifier:identifier undoManager:self.documentUndoManager];
        self.editors[identifier] = editor;
        [self addChildViewController:editor];
        __weak FWManuscriptViewController *owner = self;
        editor.textDidChange = ^{
            FWManuscriptViewController *controller = owner;
            if (![controller.selectedUnitIdentifier isEqual:identifier]) [controller selectUnitWithIdentifier:identifier];
            if (controller.workDidChange) controller.workDidChange();
        };
        editor.undoDidChangeText = ^{ [owner selectUnitWithIdentifier:identifier]; };
    }
    self.activeEditor = editor;
    self.selectedUnitIdentifier = identifier;
    editor.view.frame = self.editorHost.bounds;
    editor.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.editorHost addSubview:editor.view];
    if (self.documentWindowController) [editor connectToolbar:self.documentWindowController];
    self.updatingSelection = YES;
    [self.unitTable reloadData];
    NSUInteger index = [self.work.manuscript.units indexOfObject:unit];
    [self.unitTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [self.unitTable scrollRowToVisible:index];
    self.unitTitle.stringValue = unit.title;
    self.moveUpButton.enabled = index > 0;
    self.moveDownButton.enabled = index + 1 < self.work.manuscript.units.count;
    self.updatingSelection = NO;
    [self.view.window makeFirstResponder:editor.textView];
}
- (void)applyManuscript:(FKManuscript *)manuscript selection:(NSString *)identifier name:(NSString *)name {
    FKManuscript *before = self.work.manuscript;
    NSString *selection = self.selectedUnitIdentifier;
    [self.activeEditor.textView breakUndoCoalescing];
    [self.documentUndoManager registerUndoWithTarget:self handler:^(FWManuscriptViewController *controller) {
        [controller applyManuscript:before selection:selection name:name];
    }];
    self.work.manuscript = manuscript;
    [self selectUnitWithIdentifier:identifier];
    [self.documentUndoManager setActionName:name];
    if (self.workDidChange) self.workDidChange();
}
- (IBAction)addContentUnit:(id)sender {
    NSMutableArray *units = [self.work.manuscript.units mutableCopy];
    FKText *unit = [FKText new];
    [units addObject:unit];
    [self applyManuscript:[[FKManuscript alloc] initWithIdentifier:self.work.manuscriptIdentifier units:units]
        selection:unit.identifier name:NSLocalizedStringWithDefaultValue(@"manuscript.add-content-unit", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Add Content Unit", @"Add a unit to the Manuscript. Accessibility label and undo action name; Content Unit is a Folio domain term.")];
    [self.view.window makeFirstResponder:self.unitTitle];
    [self.unitTitle selectText:nil];
}
- (IBAction)renameContentUnit:(id)sender {
    FKText *unit = [self.work textWithIdentifier:self.selectedUnitIdentifier];
    NSString *title = [self.unitTitle.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!title.length) title = NSLocalizedStringWithDefaultValue(@"content-unit.empty-title", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Untitled", @"Title saved when the user submits an empty Content Unit title. Match the default title in FolioKit.");
    if ([unit.title isEqual:title]) return;
    NSMutableArray *units = [self.work.manuscript.units mutableCopy];
    units[[units indexOfObject:unit]] = [[FKText alloc] initWithIdentifier:unit.identifier title:title
        paragraphs:unit.paragraphs formattingWarningDismissed:unit.formattingWarningDismissed];
    [self applyManuscript:[[FKManuscript alloc] initWithIdentifier:self.work.manuscriptIdentifier units:units]
        selection:unit.identifier name:NSLocalizedStringWithDefaultValue(@"manuscript.rename-content-unit.undo", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Rename Content Unit", @"Undo action name for editing a Content Unit title; AppKit adds Undo or Redo.")];
}
- (void)moveBy:(NSInteger)delta {
    NSMutableArray *units = [self.work.manuscript.units mutableCopy];
    NSInteger index = [units indexOfObject:[self.work textWithIdentifier:self.selectedUnitIdentifier]];
    NSInteger destination = index + delta;
    if (destination < 0 || destination >= (NSInteger)units.count) return;
    [units exchangeObjectAtIndex:index withObjectAtIndex:destination];
    [self applyManuscript:[[FKManuscript alloc] initWithIdentifier:self.work.manuscriptIdentifier units:units]
        selection:self.selectedUnitIdentifier name:NSLocalizedStringWithDefaultValue(@"manuscript.reorder-content-unit.undo", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"], @"Reorder Content Unit", @"Undo action name for moving a Content Unit; AppKit adds Undo or Redo.")];
}
- (IBAction)moveContentUnitUp:(id)sender { [self moveBy:-1]; }
- (IBAction)moveContentUnitDown:(id)sender { [self moveBy:1]; }
@end
