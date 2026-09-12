// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

//
//  WriteUITests.m
//  WriteUITests
//
//  Created by Justin Croonenberghs on 9/6/26.
//

#import <XCTest/XCTest.h>

@interface WriteUITests : XCTestCase

@end

@implementation WriteUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSemanticFormattingToolbarAndHelp {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
    [app typeKey:@"n" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *text = app.textViews[@"manuscriptText"].firstMatch;
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    [text click];
    [text typeText:@"Formatting sample"];
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *emphasis = app.checkBoxes[@"Emphasis"].firstMatch;
    XCTAssertTrue(emphasis.exists);
    [emphasis click];
    NSString *semanticOn = [emphasis.value description];
    [XCUIElement performWithKeyModifiers:XCUIKeyModifierOption block:^{ [emphasis click]; }];
    XCTAssertEqualObjects([emphasis.value description], semanticOn);
    [emphasis click];
    XCTAssertNotEqualObjects([emphasis.value description], semanticOn);
    [app.toolbars.buttons[@"Appearance"].firstMatch click];
    XCTAssertTrue([app.popovers.firstMatch waitForExistenceWithTimeout:3]);
    for (NSString *label in @[@"Bold", @"Italic", @"Underline", @"Strikethrough"]) {
        XCUIElement *checkbox = app.popovers.checkBoxes[label].firstMatch;
        XCTAssertTrue(checkbox.exists);
        NSString *before = [checkbox.value description];
        [checkbox click];
        XCTAssertNotEqualObjects([checkbox.value description], before);
        XCTAssertTrue(app.popovers.firstMatch.exists);
    }
    XCTAttachment *appearance = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    appearance.name = @"Appearance formatting popover";
    appearance.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:appearance];
    [app typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
    [app.toolbars.buttons[@"Formatting Help"].firstMatch click];
    XCTAssertTrue([app.popovers.firstMatch waitForExistenceWithTimeout:3]);
    XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    screenshot.name = @"Semantic formatting help";
    screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:screenshot];
    [app typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
    // This test's text is disposable; clear it before the test runner exits.
    [text click];
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [text typeKey:XCUIKeyboardKeyDelete modifierFlags:0];
}

- (void)testFormattingConflictOffersConversionWithoutChangingWords {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch]; [app typeKey:@"n" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *text = app.textViews[@"manuscriptText"].firstMatch;
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    [text click]; [text typeText:@"Keep these words"];
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [text typeKey:@"b" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierOption];
    [app.checkBoxes[@"Emphasis"].firstMatch click];
    XCUIElement *marker = app.buttons[@"formattingConflictMarker"].firstMatch;
    XCTAssertTrue([marker waitForExistenceWithTimeout:3]);
    // The inline marker is a control, never a character in the authored text.
    XCTAssertEqualObjects(text.value, @"Keep these words");
    [text typeKey:XCUIKeyboardKeyRightArrow modifierFlags:0];
    XCTAttachment *inlineScreenshot = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    inlineScreenshot.name = @"Inline semantic diagnostic";
    inlineScreenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:inlineScreenshot];
    [marker click];
    XCUIElement *convert = app.buttons[@"Convert to Semantic Emphasis"].firstMatch;
    XCTAssertTrue([convert waitForExistenceWithTimeout:3]);
    XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    screenshot.name = @"Semantic presentation conflict"; screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:screenshot];
    [convert click];
    XCTAssertFalse(convert.exists);
    XCTAssertFalse(marker.exists);
    XCTAssertEqualObjects(text.value, @"Keep these words");
    // Exercise the document's real responder-chain undo, with native event grouping.
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertTrue([marker waitForExistenceWithTimeout:3]);
    XCTAssertEqualObjects(text.value, @"Keep these words");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertFalse(marker.exists);
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertTrue([marker waitForExistenceWithTimeout:3]);
    [marker click];
    [app.buttons[@"Keep Presentation / Dismiss"].firstMatch click];
    XCTAssertFalse(marker.exists);
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertTrue([marker waitForExistenceWithTimeout:3]);
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertFalse(marker.exists);
    XCTAssertEqualObjects(text.value, @"Keep these words");
    [text click]; [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [text typeKey:XCUIKeyboardKeyDelete modifierFlags:0];
}
- (void)testNativeUndoRedoRestoresTypingDeletionAndSemanticControls {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch]; [app typeKey:@"n" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *text = app.textViews[@"manuscriptText"].firstMatch;
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    [text click]; [text typeText:@"Undo these words"];
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertEqualObjects(text.value, @"");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertEqualObjects(text.value, @"Undo these words");
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *emphasis = app.checkBoxes[@"Emphasis"].firstMatch;
    NSString *off = [emphasis.value description];
    [emphasis click];
    NSString *on = [emphasis.value description];
    XCTAssertNotEqualObjects(on, off);
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertEqualObjects([emphasis.value description], off);
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertEqualObjects([emphasis.value description], on);
    [text typeKey:XCUIKeyboardKeyDelete modifierFlags:0];
    XCTAssertEqualObjects(text.value, @"");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertEqualObjects(text.value, @"Undo these words");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertEqualObjects(text.value, @"");
}
- (void)testManuscriptSidebarAddsRenamesSwitchesAndReordersUnits {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch]; [app typeKey:@"n" modifierFlags:XCUIKeyModifierCommand];
    XCUIElement *text = app.textViews[@"manuscriptText"].firstMatch;
    XCUIElement *table = app.tables[@"manuscriptUnits"].firstMatch;
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    XCTAssertTrue(table.exists);
    [text click]; [text typeText:@"First unit words"];
    [app.buttons[@"Add Content Unit"].firstMatch click];
    XCUIElement *title = app.textFields[@"contentUnitTitle"].firstMatch;
    [title typeText:@"Second Unit"];
    [title typeKey:XCUIKeyboardKeyReturn modifierFlags:0];
    XCTAssertEqual(table.tableRows.count, 2u);
    XCTAssertEqualObjects(text.value, @"");
    [text typeText:@"Second unit words"];
    [[table.tableRows elementBoundByIndex:0] click];
    XCTAssertEqualObjects(text.value, @"First unit words");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand];
    XCTAssertEqualObjects(text.value, @"");
    XCTAssertEqualObjects(title.value, @"Second Unit");
    [app typeKey:@"z" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierShift];
    XCTAssertEqualObjects(text.value, @"Second unit words");
    [app.buttons[@"Move Content Unit Up"].firstMatch click];
    XCTAssertFalse(app.buttons[@"Move Content Unit Up"].firstMatch.enabled);
    XCTAssertEqualObjects(text.value, @"Second unit words");
    [[table.tableRows elementBoundByIndex:1] click];
    XCTAssertEqualObjects(text.value, @"First unit words");
    [title click]; [title typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [title typeText:@"First Unit"];
    // Leaving the title field commits the rename before another unit becomes active.
    [[table.tableRows elementBoundByIndex:0] click];
    XCTAssertEqualObjects(text.value, @"Second unit words");
    XCTAssertEqualObjects(title.value, @"Second Unit");
    [[table.tableRows elementBoundByIndex:1] click];
    XCTAssertEqualObjects(title.value, @"First Unit");
    XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    screenshot.name = @"Manuscript sidebar with two Content Units";
    screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:screenshot];
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [text typeKey:XCUIKeyboardKeyDelete modifierFlags:0];
    [[table.tableRows elementBoundByIndex:0] click];
    [text typeKey:@"a" modifierFlags:XCUIKeyModifierCommand];
    [text typeKey:XCUIKeyboardKeyDelete modifierFlags:0];
}
- (void)testLaunchPerformance {
    // This measures how long it takes to launch your application.
    [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
        [[[XCUIApplication alloc] init] launch];
    }];
}

@end
