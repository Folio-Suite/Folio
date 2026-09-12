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
    FWManuscriptViewController *editor = [[FWManuscriptViewController alloc] initWithWork:self.work undoManager:self.undoManager];
    __weak FWDocument *document = self;
    editor.workDidChange = ^{
        FWDocument *strongDocument = document;
        if (!strongDocument.undoManager.isUndoing && !strongDocument.undoManager.isRedoing) {
            [strongDocument updateChangeCount:NSChangeDone];
        }
    };
    NSWindowController *controller = [editor makeWindowController];
    [controller.window center];
    [self addWindowController:controller];
}
- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    return [self.work fileWrapperWithError:outError];
}
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    FWWork *work = [[FWWork alloc] initWithFileWrapper:fileWrapper error:outError];
    if (!work) return NO;
    [self.undoManager removeAllActions];
    _work = work;
    for (NSWindowController *controller in self.windowControllers) {
        FWManuscriptViewController *editor = (FWManuscriptViewController *)controller.contentViewController;
        editor.work = work;
    }
    return YES;
}
@end
