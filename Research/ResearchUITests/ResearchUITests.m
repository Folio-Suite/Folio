// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

//
//  ResearchUITests.m
//  ResearchUITests
//
//  Created by Justin Croonenberghs on 9/6/26.
//

#import <XCTest/XCTest.h>

@interface ResearchUITests : XCTestCase

@end

@implementation ResearchUITests

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
    [app.menuBars.menuBarItems[@"Research"] click];
    [app.menuItems[@"About Research"] click];
    XCTAssertTrue([app.staticTexts[expected].firstMatch waitForExistenceWithTimeout:5]);
    [app terminate];
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testLaunchPerformance {
    // This measures how long it takes to launch your application.
    [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
        [[[XCUIApplication alloc] init] launch];
    }];
}

@end
