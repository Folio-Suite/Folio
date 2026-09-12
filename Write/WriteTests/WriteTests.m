// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <XCTest/XCTest.h>
#import "../Write/FWDocument.h"
#import <WriteKit/WriteKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface WriteTests : XCTestCase
@end

@implementation WriteTests
- (void)testDocumentWritesAndReopensNativePackage {
    FWDocument *document = [FWDocument new];
    [document makeWindowControllers];
    FWManuscriptViewController *manuscript = (FWManuscriptViewController *)document.windowControllers.firstObject.contentViewController;
    FWEditorViewController *editor = manuscript.activeEditor;
    (void)editor.view;
    [editor.textView insertText:@"A beginning.\nAnother paragraph." replacementRange:NSMakeRange(0, 0)];
    editor.textView.selectedRange = NSMakeRange(2, 9);
    [editor toggleBold:nil];
    [manuscript addContentUnit:nil];
    NSTextField *title = [manuscript valueForKey:@"unitTitle"];
    title.stringValue = @"Next Chapter";
    [manuscript renameContentUnit:nil];
    [manuscript.activeEditor.textView insertText:@"Independent second unit." replacementRange:NSMakeRange(0, 0)];
    NSString *secondIdentifier = manuscript.selectedUnitIdentifier;
    NSError *error = nil;
    NSURL *URL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"fwdoc"]]];
    @try {
        XCTAssertTrue([document writeToURL:URL ofType:FWWorkDocumentType error:&error], @"%@", error);
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[URL.path stringByAppendingPathComponent:@"Work.sqlite"]]);
        NSString *detectedType = [NSDocumentController.sharedDocumentController typeForContentsOfURL:URL error:&error];
        XCTAssertNotNil(detectedType, @"%@", error);
        if (!detectedType) return;
        UTType *type = [UTType typeWithIdentifier:detectedType];
        XCTAssertEqualObjects(type, [UTType typeWithIdentifier:FWWorkDocumentType]);
        XCTAssertTrue([type conformsToType:UTTypePackage]);
        XCTAssertTrue([type conformsToType:UTTypeContent]);
        FWDocument *loaded = [[FWDocument alloc] initWithContentsOfURL:URL ofType:detectedType error:&error];
        XCTAssertNotNil(loaded, @"%@", error);
        [loaded makeWindowControllers];
        FWEditorViewController *reopened = [(FWManuscriptViewController *)loaded.windowControllers.firstObject.contentViewController activeEditor];
        (void)reopened.view;
        XCTAssertEqualObjects(reopened.textView.string, editor.textView.string);
        NSFont *font = [reopened.textView.textStorage attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL];
        XCTAssertTrue([NSFontManager.sharedFontManager traitsOfFont:font] & NSBoldFontMask);
        FWManuscriptViewController *loadedManuscript = (FWManuscriptViewController *)loaded.windowControllers.firstObject.contentViewController;
        [loadedManuscript selectUnitWithIdentifier:secondIdentifier];
        XCTAssertEqualObjects(loadedManuscript.activeEditor.textView.string, @"Independent second unit.");
        XCTAssertEqualObjects([(NSTextField *)[loadedManuscript valueForKey:@"unitTitle"] stringValue], @"Next Chapter");
        [loaded close];
    } @finally {
        [document close];
        [NSFileManager.defaultManager removeItemAtURL:URL error:NULL];
    }
}
@end
