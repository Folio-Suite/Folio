#import <XCTest/XCTest.h>
#import <WriteKit/WriteKit.h>
#import <FolioKit/FolioKit.h>

@interface WriteKitTests : XCTestCase
@end

@implementation WriteKitTests
- (FWWork *)sampleWork {
    FWWork *work = [FWWork new];
    NSArray *runs = @[
        [[FKTextRun alloc] initWithString:@"Meaning & <words> 👑 " meaning:FKTextMeaningEmphasis appearance:0],
        [[FKTextRun alloc] initWithString:@"strong" meaning:FKTextMeaningStrongEmphasis appearance:0],
        [[FKTextRun alloc] initWithString:@" bold italic  " meaning:0 appearance:FKTextAppearanceBold | FKTextAppearanceItalic]
    ];
    FKParagraph *paragraph = [[FKParagraph alloc] initWithIdentifier:@"paragraph-one" runs:runs alignment:FKParagraphAlignmentCenter];
    work.text = [[FKText alloc] initWithIdentifier:work.text.identifier paragraphs:@[paragraph, [FKParagraph new], [FKParagraph new]]];
    return work;
}
- (void)testNativePackageRoundTripPreservesMeaningAppearanceWhitespaceAndIdentity {
    FWWork *work = [self sampleWork];
    NSError *error = nil;
    NSFileWrapper *package = [work fileWrapperWithError:&error];
    XCTAssertNotNil(package, @"%@", error);
    XCTAssertEqualObjects(package.fileWrappers.allKeys, (@[@"Work.sqlite"]));
    NSData *data = package.fileWrappers[@"Work.sqlite"].regularFileContents;
    XCTAssertTrue(data.length > 16);
    XCTAssertEqualObjects([[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 15)] encoding:NSASCIIStringEncoding], @"SQLite format 3");
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertEqualObjects(loaded.identifier, work.identifier);
    XCTAssertEqualObjects(loaded.manuscriptIdentifier, work.manuscriptIdentifier);
    XCTAssertEqualObjects(loaded.text.identifier, work.text.identifier);
    XCTAssertEqualObjects(loaded.text.string, work.text.string);
    XCTAssertEqual(loaded.text.paragraphs.count, 3u);
    for (NSUInteger i = 0; i < 3; i++) XCTAssertEqualObjects(loaded.text.paragraphs[i].identifier, work.text.paragraphs[i].identifier);
    FKParagraph *paragraph = loaded.text.paragraphs.firstObject;
    XCTAssertEqual(paragraph.alignment, FKParagraphAlignmentCenter);
    XCTAssertEqual(paragraph.runs[0].meaning, FKTextMeaningEmphasis);
    XCTAssertEqual(paragraph.runs[0].appearance, FKTextAppearancePlain);
    XCTAssertEqual(paragraph.runs[1].meaning, FKTextMeaningStrongEmphasis);
    XCTAssertEqual(paragraph.runs[2].meaning, FKTextMeaningNone);
    XCTAssertEqual(paragraph.runs[2].appearance, FKTextAppearanceBold | FKTextAppearanceItalic);
}
- (void)testEmptyWorkCanBeSavedAndReopened {
    FWWork *work = [FWWork new];
    NSError *error = nil;
    NSFileWrapper *package = [work fileWrapperWithError:&error];
    XCTAssertNotNil(package, @"%@", error);
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
    XCTAssertEqualObjects(loaded.text.string, @"");
    XCTAssertEqual(loaded.text.paragraphs.count, 1u);
}
- (void)testUnknownPackageContentsAreRejectedWithoutChangingOriginal {
    NSError *error = nil;
    NSFileWrapper *package = [[self sampleWork] fileWrapperWithError:&error];
    NSData *original = package.fileWrappers[@"Work.sqlite"].regularFileContents;
    [package addRegularFileWithContents:[@"future content" dataUsingEncoding:NSUTF8StringEncoding] preferredFilename:@"future.bin"];
    XCTAssertNil([[FWWork alloc] initWithFileWrapper:package error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(package.fileWrappers[@"Work.sqlite"].regularFileContents, original);
    XCTAssertNotNil(package.fileWrappers[@"future.bin"]);
}
- (void)testCorruptStoreIsRejected {
    NSFileWrapper *package = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{
        @"Work.sqlite":[[NSFileWrapper alloc] initRegularFileWithContents:[@"not a database" dataUsingEncoding:NSUTF8StringEncoding]]}];
    NSError *error = nil;
    XCTAssertNil([[FWWork alloc] initWithFileWrapper:package error:&error]);
    XCTAssertNotNil(error);
}
- (void)testDuplicateParagraphIdentityCannotBeSaved {
    FWWork *work = [self sampleWork];
    FKParagraph *paragraph = work.text.paragraphs.firstObject;
    work.text = [[FKText alloc] initWithIdentifier:work.text.identifier paragraphs:@[paragraph, paragraph]];
    NSError *error = nil;
    XCTAssertNil([work fileWrapperWithError:&error]);
    XCTAssertNotNil(error);
}
- (void)testEditorFormattingUndoAndParagraphIdentity {
    FWWork *work = [FWWork new];
    NSString *paragraphID = work.text.paragraphs.firstObject.identifier;
    NSUndoManager *undo = [NSUndoManager new];
    undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    [undo beginUndoGrouping];
    [editor.textView insertText:@"Hello world" replacementRange:NSMakeRange(0, 0)];
    [editor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    XCTAssertEqualObjects(work.text.string, @"Hello world");
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.identifier, paragraphID);
    editor.textView.selectedRange = NSMakeRange(0, 5);
    [undo beginUndoGrouping];
    [editor toggleEmphasis:nil];
    [undo endUndoGrouping];
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.meaning, FKTextMeaningEmphasis);
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.appearance, FKTextAppearancePlain);
    XCTAssertEqualObjects(editor.textView.undoManager, undo);
    XCTAssertTrue(undo.canUndo);
    [undo undo];
    XCTAssertEqualObjects([editor.textView.textStorage attribute:@"FolioTextMeaning" atIndex:0 effectiveRange:NULL], @0);
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.meaning, FKTextMeaningNone);
    XCTAssertEqualObjects(work.text.string, @"Hello world");
    [undo redo];
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.meaning, FKTextMeaningEmphasis);
}
- (void)testTypingUndoRedoKeepsVisibleSemanticAndSavedTextInAgreement {
    FWWork *work = [FWWork new];
    NSString *originalParagraphIdentifier = work.text.paragraphs.firstObject.identifier;
    NSUndoManager *undo = [NSUndoManager new];
    undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    NSString *typed = @"Café 👩🏽‍💻\nA second paragraph.";
    [undo beginUndoGrouping];
    [editor.textView insertText:typed replacementRange:NSMakeRange(0, 0)];
    [editor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    NSArray *typedIdentifiers = [work.text.paragraphs valueForKey:@"identifier"];

    for (NSNumber *step in @[@0, @1, @2]) {
        if (step.integerValue == 1) [undo undo];
        if (step.integerValue == 2) [undo redo];
        NSString *expected = step.integerValue == 1 ? @"" : typed;
        XCTAssertEqualObjects(editor.textView.string, expected);
        XCTAssertEqualObjects(work.text.string, expected);
        XCTAssertEqualObjects(work.text.paragraphs.firstObject.identifier, originalParagraphIdentifier);
        if (step.integerValue != 1) XCTAssertEqualObjects([work.text.paragraphs valueForKey:@"identifier"], typedIdentifiers);
        NSError *error = nil;
        NSFileWrapper *package = [work fileWrapperWithError:&error];
        XCTAssertNotNil(package, @"%@", error);
        FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
        XCTAssertNotNil(loaded, @"%@", error);
        XCTAssertEqualObjects(loaded.text.string, expected);
        XCTAssertEqualObjects([loaded.text.paragraphs valueForKey:@"identifier"], [work.text.paragraphs valueForKey:@"identifier"]);
    }
}
- (void)testSplittingParagraphMakesDistinctIdentityAndRetainsOriginal {
    FWWork *work = [FWWork new];
    NSString *paragraphID = work.text.paragraphs.firstObject.identifier;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:[NSUndoManager new]];
    (void)editor.view;
    [editor.textView insertText:@"First\nSecond\n" replacementRange:NSMakeRange(0, 0)];
    XCTAssertEqualObjects(work.text.string, @"First\nSecond\n");
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.identifier, paragraphID);
    NSSet *identifiers = [NSSet setWithArray:[work.text.paragraphs valueForKey:@"identifier"]];
    XCTAssertEqual(identifiers.count, 3u);
    NSError *error = nil;
    XCTAssertNotNil([work fileWrapperWithError:&error], @"%@", error);
}
- (void)testInternalCopyPasteRetainsMeaningButCreatesIndependentParagraphs {
    FWWork *work = [FWWork new];
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:[NSUndoManager new]];
    (void)editor.view;
    [editor.textView insertText:@"Original" replacementRange:NSMakeRange(0, 0)];
    editor.textView.selectedRange = NSMakeRange(0, 8);
    [editor toggleStrongEmphasis:nil];
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    @try {
        XCTAssertTrue([editor.textView writeSelectionToPasteboard:pasteboard types:editor.textView.writablePasteboardTypes]);
        editor.textView.selectedRange = NSMakeRange(8, 0);
        [editor.textView insertText:@"\n" replacementRange:editor.textView.selectedRange];
        NSString *destinationIdentifier = work.text.paragraphs.lastObject.identifier;
        XCTAssertTrue([editor.textView readSelectionFromPasteboard:pasteboard]);
        XCTAssertEqualObjects(work.text.string, @"Original\nOriginal");
        XCTAssertNotEqualObjects(work.text.paragraphs[0].identifier, work.text.paragraphs[1].identifier);
        XCTAssertEqualObjects(work.text.paragraphs[1].identifier, destinationIdentifier);
        XCTAssertEqual(work.text.paragraphs[1].runs.firstObject.meaning, FKTextMeaningStrongEmphasis);
        XCTAssertEqual(work.text.paragraphs[1].runs.firstObject.appearance, FKTextAppearancePlain);
    } @finally {
        [pasteboard releaseGlobally];
    }
}

@end
