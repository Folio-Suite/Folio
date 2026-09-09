// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWDocument.h"
#import <WriteKit/WriteKit.h>

@implementation FWDocument
- (instancetype)init {
    if ((self = [super init])) {
        _work = [FWWork new];
        self.hasUndoManager = YES;
    }
    return self;
}
+ (BOOL)autosavesInPlace { return YES; }
- (void)makeWindowControllers {
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:self.work undoManager:self.undoManager];
    __weak FWDocument *document = self;
    editor.textDidChange = ^{
        FWDocument *strongDocument = document;
        if (!strongDocument.undoManager.isUndoing && !strongDocument.undoManager.isRedoing) {
            [strongDocument updateChangeCount:NSChangeDone];
        }
    };
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.contentMinSize = NSMakeSize(620, 360);
    window.contentViewController = editor;
    [window setFrameAutosaveName:@"WriteEditor"];
    [window center];
    [self addWindowController:[[NSWindowController alloc] initWithWindow:window]];
}
- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    return [self.work fileWrapperWithError:outError];
}
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    FWWork *work = [[FWWork alloc] initWithFileWrapper:fileWrapper error:outError];
    if (!work) return NO;
    _work = work;
    for (NSWindowController *controller in self.windowControllers) {
        FWEditorViewController *editor = (FWEditorViewController *)controller.contentViewController;
        editor.work = work;
    }
    return YES;
}
@end
