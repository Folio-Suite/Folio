#import <XCTest/XCTest.h>
#import <FolioKit/FolioKit.h>

@interface FolioKitTests : XCTestCase
@end

@implementation FolioKitTests
- (void)testPackageStagingReturnsIndependentContentAndRemovesTemporaryFiles {
    __block NSURL *stagingDirectory;
    NSError *error = nil;
    NSData *expected = [@"A staged package" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *result = [FKPackageSupport withTemporaryDirectoryWithError:&error operation:^id(NSURL *directory, NSError **operationError) {
        stagingDirectory = directory;
        NSURL *file = [directory URLByAppendingPathComponent:@"content"];
        if (![expected writeToURL:file options:NSDataWritingAtomic error:operationError]) return nil;
        return [NSData dataWithContentsOfURL:file options:0 error:operationError];
    }];
    XCTAssertNil(error);
    XCTAssertEqualObjects(result, expected);
    XCTAssertNotNil(stagingDirectory);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:stagingDirectory.path]);
}

- (void)testPackageStagingPropagatesFailureAndRemovesTemporaryDirectory {
    __block NSURL *stagingDirectory;
    NSError *expected = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    NSError *error = nil;
    id result = [FKPackageSupport withTemporaryDirectoryWithError:&error operation:^id(NSURL *directory, NSError **operationError) {
        stagingDirectory = directory;
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:directory.path]);
        if (operationError) *operationError = expected;
        return nil;
    }];
    XCTAssertNil(result);
    XCTAssertEqualObjects(error, expected);
    XCTAssertNotNil(stagingDirectory);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:stagingDirectory.path]);
}

- (void)testNestedStagingUsesIndependentDirectoriesAndCleansUpAfterException {
    __block NSURL *outerDirectory;
    __block NSURL *innerDirectory;
    NSException *expected = [NSException exceptionWithName:@"StagingProbe" reason:nil userInfo:nil];
    XCTAssertThrowsSpecificNamed([FKPackageSupport withTemporaryDirectoryWithError:NULL operation:^id(NSURL *outer, NSError **outerError) {
        outerDirectory = outer;
        return [FKPackageSupport withTemporaryDirectoryWithError:outerError operation:^id(NSURL *inner, NSError **innerError) {
            innerDirectory = inner;
            XCTAssertNotEqualObjects(inner, outer);
            XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:outer.path]);
            @throw expected;
        }];
    }], NSException, @"StagingProbe");
    XCTAssertNotNil(outerDirectory);
    XCTAssertNotNil(innerDirectory);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:outerDirectory.path]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:innerDirectory.path]);
}
@end
