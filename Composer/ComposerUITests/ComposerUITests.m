// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <XCTest/XCTest.h>

@interface ComposerUITests : XCTestCase
@end

@implementation ComposerUITests
- (void)testAboutPanelReportsSuiteIdentity {
    NSBundle *testBundle = [NSBundle bundleForClass:self.class];
    NSString *version = [testBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *build = [testBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    XCTAssertNotNil(version);
    XCTAssertNotNil(build);
    NSString *expected = [NSString stringWithFormat:@"Version %@ (%@)", version, build];
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US"];
    [app launch];
    [app.menuBars.menuBarItems[@"Composer"] click];
    [app.menuItems[@"About Composer"] click];
    XCTAssertTrue([app.staticTexts[expected].firstMatch waitForExistenceWithTimeout:5]);
    [app terminate];
}

@end
