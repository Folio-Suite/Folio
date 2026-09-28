// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <XCTest/XCTest.h>
#import <WriteKit/WriteKit.h>
#import <FolioKit/FolioKit.h>

@interface WriteKitTests : XCTestCase
@end

@implementation WriteKitTests
- (void)testMixedScriptAuthoredTitleAndTextSurvivePackageRoundTrip {
    FWWork *work = [FWWork new];
    NSString *title = @"العربية — 日本語 — Untitled";
    NSString *text = @"العربية English עברית 日本語 한글 e\u0301 👩🏽‍💻";
    FKTextRun *run = [[FKTextRun alloc] initWithString:text emphasis:FKTextEmphasisNone presentation:[FKTextPresentation new]];
    FKParagraph *paragraph = [[FKParagraph alloc] initWithIdentifier:@"mixed-script-paragraph" runs:@[run] alignment:FKParagraphAlignmentNatural];
    work.text = [[FKText alloc] initWithIdentifier:work.text.identifier title:title paragraphs:@[paragraph] formattingWarningDismissed:NO];
    NSError *error = nil;
    NSFileWrapper *package = [work fileWrapperWithError:&error];
    XCTAssertNotNil(package, @"%@", error);
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertEqualObjects(loaded.text.title, title);
    XCTAssertEqualObjects(loaded.text.string, text);
    XCTAssertEqual(loaded.text.paragraphs.firstObject.alignment, FKParagraphAlignmentNatural);
}

- (FWWork *)sampleWork {
    FWWork *work = [FWWork new];
    NSArray *runs = @[
        [[FKTextRun alloc] initWithString:@"Meaning & <words> 👑 " emphasis:FKTextEmphasisEmphasis presentation:[FKTextPresentation new]],
        [[FKTextRun alloc] initWithString:@"strong" emphasis:FKTextEmphasisStrongEmphasis presentation:[FKTextPresentation new]],
        [[FKTextRun alloc] initWithString:@" bold italic  " emphasis:0 presentation:[[FKTextPresentation alloc] initWithBold:YES italic:YES underline:NO strikethrough:NO]]
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
    XCTAssertEqual(paragraph.runs[0].emphasis, FKTextEmphasisEmphasis);
    XCTAssertEqualObjects(paragraph.runs[0].presentation, [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:NO strikethrough:NO]);
    XCTAssertEqual(paragraph.runs[1].emphasis, FKTextEmphasisStrongEmphasis);
    XCTAssertEqual(paragraph.runs[2].emphasis, FKTextEmphasisNone);
    XCTAssertEqualObjects(paragraph.runs[2].presentation, [[FKTextPresentation alloc] initWithBold:YES italic:YES underline:NO strikethrough:NO]);
}
- (void)testNativeOrderedRelationshipsPreserveParagraphAndRunOrder {
    FWWork *work = [FWWork new];
    NSMutableArray<FKParagraph *> *paragraphs = [NSMutableArray array];
    for (NSString *identifier in @[@"z-last-alphabetically", @"a-first-alphabetically", @"m-middle"]) {
        NSArray *runs = @[
            [[FKTextRun alloc] initWithString:@"Z" emphasis:FKTextEmphasisEmphasis presentation:[FKTextPresentation new]],
            [[FKTextRun alloc] initWithString:@"A" emphasis:0 presentation:[[FKTextPresentation alloc] initWithBold:YES italic:NO underline:NO strikethrough:NO]],
            [[FKTextRun alloc] initWithString:@"M" emphasis:FKTextEmphasisStrongEmphasis presentation:[FKTextPresentation new]]
        ];
        [paragraphs addObject:[[FKParagraph alloc] initWithIdentifier:identifier runs:runs alignment:FKParagraphAlignmentLeft]];
    }
    work.text = [[FKText alloc] initWithIdentifier:work.text.identifier paragraphs:paragraphs];
    for (NSUInteger pass = 0; pass < 2; pass++) {
        NSError *error = nil;
        NSFileWrapper *package = [work fileWrapperWithError:&error];
        XCTAssertNotNil(package, @"%@", error);
        FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
        XCTAssertNotNil(loaded, @"%@", error);
        XCTAssertEqualObjects([loaded.text.paragraphs valueForKey:@"identifier"], [paragraphs valueForKey:@"identifier"]);
        for (FKParagraph *paragraph in loaded.text.paragraphs) {
            XCTAssertEqualObjects([paragraph.runs valueForKey:@"string"], (@[@"Z", @"A", @"M"]));
            XCTAssertEqualObjects(paragraph.runs[1].presentation, [[FKTextPresentation alloc] initWithBold:YES italic:NO underline:NO strikethrough:NO]);
        }
        work = loaded;
    }
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
- (void)testExclusiveEmphasisPreservesPresentationAndSplitsOnlyTheSelectedWord {
    FWWork *work = [FWWork new];
    NSUndoManager *undo = [NSUndoManager new]; undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    [undo beginUndoGrouping];
    [editor.textView insertText:@"before word after" replacementRange:NSMakeRange(0, 0)];
    editor.textView.selectedRange = NSMakeRange(0, 17);
    [editor toggleEmphasis:nil];
    [undo endUndoGrouping];
    editor.textView.selectedRange = NSMakeRange(7, 4);
    [undo beginUndoGrouping]; [editor toggleBold:nil]; [undo endUndoGrouping];
    NSArray<FKTextRun *> *runs = work.text.paragraphs.firstObject.runs;
    XCTAssertEqual(runs.count, 3u);
    XCTAssertEqualObjects([runs valueForKey:@"string"], (@[@"before ", @"word", @" after"]));
    XCTAssertFalse(runs[0].presentation.bold); XCTAssertTrue(runs[1].presentation.bold); XCTAssertFalse(runs[2].presentation.bold);
    for (FKTextRun *run in runs) XCTAssertEqual(run.emphasis, FKTextEmphasisEmphasis);
    NSFont *font = [editor.textView.textStorage attribute:NSFontAttributeName atIndex:7 effectiveRange:NULL];
    NSFontTraitMask traits = [NSFontManager.sharedFontManager traitsOfFont:font];
    XCTAssertTrue(traits & NSBoldFontMask); XCTAssertTrue(traits & NSItalicFontMask);
    XCTAssertGreaterThan([[editor valueForKey:@"formattingMarkers"] count], 0u);
    XCTAssertNotNil([editor.textView.layoutManager temporaryAttribute:NSBackgroundColorAttributeName atCharacterIndex:7 effectiveRange:NULL]);
    editor.textView.selectedRange = NSMakeRange(0, 17);
    [undo beginUndoGrouping]; [editor toggleStrongEmphasis:nil]; [undo endUndoGrouping];
    for (FKTextRun *run in work.text.paragraphs.firstObject.runs) XCTAssertEqual(run.emphasis, FKTextEmphasisStrongEmphasis);
    XCTAssertTrue(work.text.paragraphs.firstObject.runs[1].presentation.bold);
    [undo undo];
    for (FKTextRun *run in work.text.paragraphs.firstObject.runs) XCTAssertEqual(run.emphasis, FKTextEmphasisEmphasis);
    [undo beginUndoGrouping]; [editor toggleVeryStrongEmphasis:nil]; [undo endUndoGrouping];
    for (FKTextRun *run in work.text.paragraphs.firstObject.runs) XCTAssertEqual(run.emphasis, FKTextEmphasisVeryStrongEmphasis);
}
- (void)testConflictConversionIsUndoableAndPersistsExclusiveMeaningAndBooleans {
    FWWork *work = [FWWork new];
    FKTextPresentation *presentation = [[FKTextPresentation alloc] initWithBold:YES italic:NO underline:YES strikethrough:YES];
    FKTextRun *run = [[FKTextRun alloc] initWithString:@"Keep these words" emphasis:FKTextEmphasisEmphasis presentation:presentation];
    work.text = [[FKText alloc] initWithIdentifier:work.text.identifier paragraphs:@[[[FKParagraph alloc]
        initWithIdentifier:@"p" runs:@[run] alignment:FKParagraphAlignmentCenter]]];
    NSUndoManager *undo = [NSUndoManager new]; undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    [editor convertPresentationToEmphasis:nil];
    run = work.text.paragraphs.firstObject.runs.firstObject;
    XCTAssertEqual(run.emphasis, FKTextEmphasisVeryStrongEmphasis);
    XCTAssertFalse(run.presentation.bold); XCTAssertFalse(run.presentation.italic);
    XCTAssertTrue(run.presentation.underline); XCTAssertTrue(run.presentation.strikethrough);
    XCTAssertTrue(work.text.formattingWarningDismissed);
    XCTAssertEqual([[editor valueForKey:@"formattingMarkers"] count], 0u);
    [undo undo];
    run = work.text.paragraphs.firstObject.runs.firstObject;
    XCTAssertEqual(run.emphasis, FKTextEmphasisEmphasis); XCTAssertTrue(run.presentation.bold);
    XCTAssertFalse(work.text.formattingWarningDismissed);
    [undo redo];
    NSError *error = nil;
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:[work fileWrapperWithError:&error] error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertTrue(loaded.text.formattingWarningDismissed);
    XCTAssertEqualObjects(loaded.text.string, @"Keep these words");
    XCTAssertEqual(loaded.text.paragraphs.firstObject.alignment, FKParagraphAlignmentCenter);
    run = loaded.text.paragraphs.firstObject.runs.firstObject;
    XCTAssertEqual(run.emphasis, FKTextEmphasisVeryStrongEmphasis);
    XCTAssertFalse(run.presentation.bold); XCTAssertFalse(run.presentation.italic);
    XCTAssertTrue(run.presentation.underline); XCTAssertTrue(run.presentation.strikethrough);
}
- (void)testWarningDismissalSurvivesEditsAndReopenWithoutChangingFormatting {
    FWWork *work = [self sampleWork];
    NSUndoManager *undo = [NSUndoManager new]; undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    editor.textView.selectedRange = NSMakeRange(0, 5);
    [undo beginUndoGrouping]; [editor toggleBold:nil]; [undo endUndoGrouping];
    [undo beginUndoGrouping]; [editor dismissFormattingWarning:nil]; [undo endUndoGrouping];
    XCTAssertTrue(work.text.paragraphs.firstObject.runs.firstObject.presentation.bold);
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisEmphasis);
    [undo beginUndoGrouping]; [editor toggleUnderline:nil]; [undo endUndoGrouping];
    XCTAssertTrue(work.text.formattingWarningDismissed);
    NSError *error = nil;
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:[work fileWrapperWithError:&error] error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    FWEditorViewController *reopened = [[FWEditorViewController alloc] initWithWork:loaded undoManager:[NSUndoManager new]];
    (void)reopened.view;
    XCTAssertTrue(loaded.text.formattingWarningDismissed);
    XCTAssertEqual([[reopened valueForKey:@"formattingMarkers"] count], 0u);
    XCTAssertNil([reopened.textView.layoutManager temporaryAttribute:NSBackgroundColorAttributeName atCharacterIndex:0 effectiveRange:NULL]);
    XCTAssertFalse([FWWork new].text.formattingWarningDismissed);
}
- (void)testAppearancePopoverCheckboxChangesSelectedText {
    FWWork *work = [self sampleWork];
    NSUndoManager *undo = [NSUndoManager new];
    undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    NSWindowController *window = [editor makeWindowController];
    [window showWindow:nil];
    editor.textView.selectedRange = NSMakeRange(0, 5);
    NSButton *button = nil;
    for (NSToolbarItem *item in window.window.toolbar.items) if ([item.label isEqualToString:@"Appearance"]) button = (NSButton *)item.view;
    XCTAssertNotNil(button);
    [button performClick:nil];
    NSPopover *popover = [editor valueForKey:@"appearancePopover"];
    XCTAssertTrue(popover.shown);
    NSButton *bold = [popover.contentViewController valueForKey:@"boldButton"];
    XCTAssertEqual(bold.state, NSControlStateValueOff);
    [undo beginUndoGrouping];
    [bold performClick:nil];
    [undo endUndoGrouping];
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, [[FKTextPresentation alloc] initWithBold:YES italic:NO underline:NO strikethrough:NO]);
    XCTAssertEqual(bold.state, NSControlStateValueOn);
    [popover close];
    [window close];
}
- (void)testAppearanceDecorationsSurviveUndoCopyAndSave {
    FWWork *work = [FWWork new];
    NSUndoManager *undo = [NSUndoManager new];
    undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    (void)editor.view;
    [undo beginUndoGrouping];
    [editor.textView insertText:@"Retained words" replacementRange:NSMakeRange(0, 0)];
    [editor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    editor.textView.selectedRange = NSMakeRange(0, editor.textView.string.length);
    [undo beginUndoGrouping];
    [editor toggleEmphasis:nil];
    [editor toggleUnderline:nil];
    [editor toggleStrikethrough:nil];
    [undo endUndoGrouping];
    FKTextPresentation *decorations = [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:YES strikethrough:YES];
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, decorations);
    XCTAssertEqualObjects([editor.textView.textStorage attribute:NSUnderlineStyleAttributeName atIndex:0 effectiveRange:NULL], @1);
    XCTAssertEqualObjects([editor.textView.textStorage attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:NULL], @1);
    [undo undo];
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, [FKTextPresentation new]);
    [undo redo];
    NSError *error = nil;
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:[work fileWrapperWithError:&error] error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertEqualObjects(loaded.text.paragraphs.firstObject.runs.firstObject.presentation, decorations);
    XCTAssertEqual(loaded.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisEmphasis);
    XCTAssertEqualObjects(loaded.text.string, @"Retained words");
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    XCTAssertTrue([editor.textView writeSelectionToPasteboard:pasteboard types:editor.textView.writablePasteboardTypes]);
    [undo beginUndoGrouping];
    XCTAssertTrue([editor.textView readSelectionFromPasteboard:pasteboard]);
    [undo endUndoGrouping];
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, decorations);
    [pasteboard releaseGlobally];
    editor.textView.selectedRange = NSMakeRange(0, editor.textView.string.length);
    [undo beginUndoGrouping];
    [editor clearFormatting:nil];
    [undo endUndoGrouping];
    XCTAssertEqualObjects([editor.textView.textStorage attribute:NSUnderlineStyleAttributeName atIndex:0 effectiveRange:NULL], @0);
    XCTAssertEqualObjects([editor.textView.textStorage attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:NULL], @0);
    XCTAssertEqualObjects(work.text.string, @"Retained words");
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
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisEmphasis);
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:NO strikethrough:NO]);
    XCTAssertEqualObjects(editor.textView.undoManager, undo);
    XCTAssertTrue(undo.canUndo);
    [undo undo];
    XCTAssertEqualObjects([editor.textView.textStorage attribute:@"FolioTextEmphasis" atIndex:0 effectiveRange:NULL], @0);
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisNone);
    XCTAssertEqualObjects(work.text.string, @"Hello world");
    [undo redo];
    XCTAssertEqual(work.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisEmphasis);
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
        XCTAssertEqual(work.text.paragraphs[1].runs.firstObject.emphasis, FKTextEmphasisStrongEmphasis);
        XCTAssertEqualObjects(work.text.paragraphs[1].runs.firstObject.presentation, [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:NO strikethrough:NO]);
    } @finally {
        [pasteboard releaseGlobally];
    }
}

- (NSButton *)formattingButtonNamed:(NSString *)title editor:(FWEditorViewController *)editor {
    NSMutableArray<NSView *> *pending = [NSMutableArray array];
    for (NSToolbarItem *item in editor.view.window.toolbar.items) if (item.view) [pending addObject:item.view];
    while (pending.count) {
        NSView *control = pending.lastObject;
        [pending removeLastObject];
        if ([control isKindOfClass:NSButton.class] && [((NSButton *)control).title isEqual:title]) return (NSButton *)control;
        [pending addObjectsFromArray:control.subviews];
    }
    XCTFail(@"Missing formatting control %@", title);
    return nil;
}
- (void)testInlineWarningsFollowWrappingWithoutChangingAuthoredText {
    FWWork *work = [FWWork new];
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:[NSUndoManager new]];
    (void)editor.view;
    NSTextView *text = editor.textView;
    NSString *words = @"First several ordinary words between the conflicts Last";
    [text setFrameSize:NSMakeSize(800, 400)];
    [text insertText:words replacementRange:NSMakeRange(0, 0)];
    for (NSString *word in @[@"First", @"Last"]) {
        text.selectedRange = [words rangeOfString:word];
        [editor toggleEmphasis:nil];
        [editor toggleBold:nil];
    }
    NSArray<NSViewController *> *markers = [editor valueForKey:@"formattingMarkers"];
    XCTAssertEqual(markers.count, 1u, @"Conflicts on the same visual line share a marker.");
    CGFloat originalY = NSMinY(markers.firstObject.view.frame);
    [text setFrameSize:NSMakeSize(220, 400)];
    markers = [editor valueForKey:@"formattingMarkers"];
    XCTAssertEqual(markers.count, 2u);
    XCTAssertGreaterThan(NSMinY(markers.lastObject.view.frame), originalY);
    for (NSViewController *marker in markers) {
        XCTAssertTrue(NSContainsRect(text.bounds, marker.view.frame));
    }
    XCTAssertEqualObjects(text.string, words);
    XCTAssertEqualObjects(work.text.string, words);
    XCTAssertNil([text.textStorage attribute:NSBackgroundColorAttributeName atIndex:0 effectiveRange:NULL]);
    XCTAssertNotNil([text.layoutManager temporaryAttribute:NSBackgroundColorAttributeName atCharacterIndex:0 effectiveRange:NULL]);
    XCTAssertNil([text.layoutManager temporaryAttribute:NSBackgroundColorAttributeName atCharacterIndex:6 effectiveRange:NULL]);
    [text setFrameSize:NSMakeSize(800, 400)];
    XCTAssertEqual([[editor valueForKey:@"formattingMarkers"] count], 1u);
    [editor dismissFormattingWarning:nil];
    XCTAssertEqual([[editor valueForKey:@"formattingMarkers"] count], 0u);
    XCTAssertNil([text.layoutManager temporaryAttribute:NSBackgroundColorAttributeName atCharacterIndex:0 effectiveRange:NULL]);
}
- (void)testFormattingControlsReflectMixedSelectionUndoAndReopenedWork {
    FWWork *work = [FWWork new];
    NSUndoManager *undo = [NSUndoManager new];
    undo.groupsByEvent = NO;
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:work undoManager:undo];
    NSWindowController *windowController = [editor makeWindowController];
    (void)windowController.window;
    XCTAssertTrue(NSEqualSizes(editor.textView.textContainerInset, NSMakeSize(32, 28)));
    NSButton *emphasis = [self formattingButtonNamed:@"Emphasis" editor:editor];
    XCTAssertNotNil(emphasis.image);
    XCTAssertEqual(emphasis.state, NSControlStateValueOff);
    [undo beginUndoGrouping];
    [editor.textView insertText:@"One two" replacementRange:NSMakeRange(0, 0)];
    [editor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    editor.textView.selectedRange = NSMakeRange(0, 3);
    [undo beginUndoGrouping];
    [emphasis performClick:nil];
    [undo endUndoGrouping];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    XCTAssertEqualObjects(work.text.paragraphs.firstObject.runs.firstObject.presentation, [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:NO strikethrough:NO]);
    editor.textView.selectedRange = NSMakeRange(0, 7);
    XCTAssertEqual(emphasis.state, NSControlStateValueMixed);
    [undo beginUndoGrouping];
    [emphasis performClick:nil];
    [undo endUndoGrouping];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    [undo undo];
    XCTAssertEqual(emphasis.state, NSControlStateValueMixed);
    [undo redo];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    NSError *error = nil;
    FWWork *reopened = [[FWWork alloc] initWithFileWrapper:[work fileWrapperWithError:&error] error:&error];
    XCTAssertNotNil(reopened, @"%@", error);
    [undo removeAllActions];
    editor.work = reopened;
    editor.textView.selectedRange = NSMakeRange(0, 7);
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    [undo beginUndoGrouping];
    [[self formattingButtonNamed:@"Clear" editor:editor] performClick:nil];
    [undo endUndoGrouping];
    XCTAssertEqual(emphasis.state, NSControlStateValueOff);
    XCTAssertEqual(reopened.text.paragraphs.firstObject.runs.firstObject.emphasis, FKTextEmphasisNone);
    [undo undo];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
}
- (void)testInsertionPointFormattingFeedbackAndClear {
    FWEditorViewController *editor = [[FWEditorViewController alloc] initWithWork:[FWWork new] undoManager:[NSUndoManager new]];
    NSWindowController *windowController = [editor makeWindowController];
    (void)windowController.window;
    NSButton *emphasis = [self formattingButtonNamed:@"Emphasis" editor:editor];
    [emphasis performClick:nil];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    [editor toggleItalic:nil];
    XCTAssertEqual(emphasis.state, NSControlStateValueOn);
    XCTAssertEqualObjects(editor.work.text.string, @"");
    [[self formattingButtonNamed:@"Clear" editor:editor] performClick:nil];
    XCTAssertEqual(emphasis.state, NSControlStateValueOff);
    [editor.textView insertText:@"Plain" replacementRange:NSMakeRange(0, 0)];
    XCTAssertEqualObjects(editor.work.text.paragraphs.firstObject.runs.firstObject.presentation, [[FKTextPresentation alloc] initWithBold:NO italic:NO underline:NO strikethrough:NO]);
}

- (void)testManuscriptUnitsRetainTextWarningsTitlesAndOrderAcrossSave {
    FWWork *work = [self sampleWork];
    FKText *first = work.text;
    FKText *second = [[FKText alloc] initWithIdentifier:[FKIdentifiedObject new].identifier title:@"Second unit"
        paragraphs:@[[FKParagraph new]] formattingWarningDismissed:YES];
    work.manuscript = [[FKManuscript alloc] initWithIdentifier:work.manuscriptIdentifier units:@[second, first]];
    NSError *error = nil;
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:[work fileWrapperWithError:&error] error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertEqualObjects([loaded.manuscript.units valueForKey:@"identifier"], (@[second.identifier, first.identifier]));
    XCTAssertEqualObjects(loaded.manuscript.units[0].title, @"Second unit");
    XCTAssertTrue(loaded.manuscript.units[0].formattingWarningDismissed);
    XCTAssertFalse(loaded.manuscript.units[1].formattingWarningDismissed);
    XCTAssertEqualObjects(loaded.manuscript.units[1].string, first.string);
    XCTAssertEqualObjects(loaded.manuscript.units[1].paragraphs.firstObject.runs[1].presentation, first.paragraphs.firstObject.runs[1].presentation);
}
- (void)testManuscriptUndoReturnsToTheUnitItChanges {
    FWWork *work = [FWWork new];
    NSUndoManager *undo = [NSUndoManager new]; undo.groupsByEvent = NO;
    FWManuscriptViewController *controller = [[FWManuscriptViewController alloc] initWithWork:work undoManager:undo];
    (void)controller.view;
    NSString *firstID = controller.selectedUnitIdentifier;
    [undo beginUndoGrouping];
    [controller.activeEditor.textView insertText:@"First words" replacementRange:NSMakeRange(0, 0)];
    [controller.activeEditor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    [undo beginUndoGrouping]; [controller addContentUnit:nil]; [undo endUndoGrouping];
    NSString *secondID = controller.selectedUnitIdentifier;
    [undo beginUndoGrouping];
    [controller.activeEditor.textView insertText:@"Second words" replacementRange:NSMakeRange(0, 0)];
    [controller.activeEditor.textView breakUndoCoalescing];
    [undo endUndoGrouping];
    XCTAssertNotEqualObjects([work textWithIdentifier:firstID].paragraphs.firstObject.identifier,
                            [work textWithIdentifier:secondID].paragraphs.firstObject.identifier, @"After typing second unit");
    [controller selectUnitWithIdentifier:firstID];
    XCTAssertEqualObjects(controller.activeEditor.textView.string, @"First words");
    [undo undo];
    XCTAssertNotEqualObjects([work textWithIdentifier:firstID].paragraphs.firstObject.identifier,
                            [work textWithIdentifier:secondID].paragraphs.firstObject.identifier, @"After undo typing");
    XCTAssertEqualObjects(controller.selectedUnitIdentifier, secondID);
    XCTAssertEqualObjects(controller.activeEditor.textView.string, @"");
    XCTAssertEqualObjects([work textWithIdentifier:firstID].string, @"First words");
    [undo undo];
    XCTAssertEqual(work.manuscript.units.count, 1u);
    XCTAssertEqualObjects(controller.selectedUnitIdentifier, firstID);
    [undo redo]; [undo redo];
    XCTAssertEqualObjects(controller.selectedUnitIdentifier, secondID);
    XCTAssertEqualObjects(controller.activeEditor.textView.string, @"Second words");
    XCTAssertEqualObjects([work textWithIdentifier:firstID].string, @"First words");
    XCTAssertNotEqualObjects([work textWithIdentifier:firstID].paragraphs.firstObject.identifier,
                            [work textWithIdentifier:secondID].paragraphs.firstObject.identifier);
    NSError *error = nil;
    NSFileWrapper *package = [work fileWrapperWithError:&error];
    XCTAssertNotNil(package, @"%@", error);
    if (!package) return;
    FWWork *loaded = [[FWWork alloc] initWithFileWrapper:package error:&error];
    XCTAssertNotNil(loaded, @"%@", error);
    XCTAssertEqualObjects([loaded.manuscript.units valueForKey:@"string"], (@[@"First words", @"Second words"]));
}
- (void)testManuscriptRenameAndReorderAreUndoableAndPreserveUnitWarningState {
    FWWork *work = [self sampleWork];
    NSUndoManager *undo = [NSUndoManager new]; undo.groupsByEvent = NO;
    FWManuscriptViewController *controller = [[FWManuscriptViewController alloc] initWithWork:work undoManager:undo];
    (void)controller.view;
    NSString *firstID = controller.selectedUnitIdentifier;
    [undo beginUndoGrouping]; [controller.activeEditor dismissFormattingWarning:nil]; [undo endUndoGrouping];
    [undo beginUndoGrouping]; [controller addContentUnit:nil]; [undo endUndoGrouping];
    NSString *secondID = controller.selectedUnitIdentifier;
    NSTextField *title = [controller valueForKey:@"unitTitle"];
    title.stringValue = @"Chapter Two";
    [undo beginUndoGrouping]; [controller renameContentUnit:nil]; [undo endUndoGrouping];
    XCTAssertEqualObjects([work textWithIdentifier:secondID].title, @"Chapter Two");
    [undo beginUndoGrouping]; [controller moveContentUnitUp:nil]; [undo endUndoGrouping];
    XCTAssertEqualObjects(work.text.identifier, secondID);
    [undo undo];
    XCTAssertEqualObjects(work.text.identifier, firstID);
    [undo undo];
    XCTAssertEqualObjects([work textWithIdentifier:secondID].title, @"Untitled");
    [undo redo]; [undo redo];
    XCTAssertEqualObjects(work.text.title, @"Chapter Two");
    XCTAssertFalse([work textWithIdentifier:secondID].formattingWarningDismissed);
    XCTAssertTrue([work textWithIdentifier:firstID].formattingWarningDismissed);
    [controller selectUnitWithIdentifier:firstID];
    XCTAssertEqual([[controller.activeEditor valueForKey:@"formattingMarkers"] count], 0u);
}

@end
