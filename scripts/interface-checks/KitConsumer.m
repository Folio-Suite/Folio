// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <FolioKit/FolioKit.h>
#import <WriteKit/WriteKit.h>
#import <ResearchKit/ResearchKit.h>
#import <ComposerKit/ComposerKit.h>

// Compile/link fixture, not a UI runner. Only the published Kits are supplied.
// Calling real entry points catches missing public implementations/re-exports.
int main(void) {
    @autoreleasepool {
        FWWork *work = [FWWork new];
        work.text = [[FKText alloc] initWithIdentifier:work.text.identifier paragraphs:@[]];
        NSUndoManager *undo = [NSUndoManager new];
        FWManuscriptViewController *manuscript = [[FWManuscriptViewController alloc]
            initWithWork:work undoManager:undo];
        FWEditorViewController *editor = [[FWEditorViewController alloc]
            initWithWork:work undoManager:undo];
        NSError *error = nil;
        NSFileWrapper *package = [work fileWrapperWithError:&error];
        NSFileWrapper *library = [FRLibraryPackage emptyPackageWithError:&error];
        id staged = [FKPackageSupport withTemporaryDirectoryWithError:&error
            operation:^id(NSURL *directory, NSError **operationError) {
                return directory.path;
            }];
        return !(manuscript && editor && package && library && staged &&
                 FolioKitVersionNumber && WriteKitVersionNumber &&
                 ResearchKitVersionNumber && ComposerKitVersionNumber);
    }
}
