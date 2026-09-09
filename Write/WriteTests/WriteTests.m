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
    FWEditorViewController *editor = (FWEditorViewController *)document.windowControllers.firstObject.contentViewController;
    (void)editor.view;
    [editor.textView insertText:@"A beginning.\nAnother paragraph." replacementRange:NSMakeRange(0, 0)];
    editor.textView.selectedRange = NSMakeRange(2, 9);
    [editor toggleBold:nil];
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
        FWEditorViewController *reopened = (FWEditorViewController *)loaded.windowControllers.firstObject.contentViewController;
        (void)reopened.view;
        XCTAssertEqualObjects(reopened.textView.string, editor.textView.string);
        NSFont *font = [reopened.textView.textStorage attribute:NSFontAttributeName atIndex:3 effectiveRange:NULL];
        XCTAssertTrue([NSFontManager.sharedFontManager traitsOfFont:font] & NSBoldFontMask);
        [loaded close];
    } @finally {
        [document close];
        [NSFileManager.defaultManager removeItemAtURL:URL error:NULL];
    }
}
@end
