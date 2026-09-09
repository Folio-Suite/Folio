#import <XCTest/XCTest.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CoreData/CoreData.h>
#import "../Research/FRDocument.h"

@interface ResearchTests : XCTestCase
@end

@implementation ResearchTests
- (void)testLibraryPackageIsRecognizedAndPreservesCollectedFilesAcrossSaves {
    NSString *libraryType = @"dev.foliosuite.Research.Library";
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    NSURL *URL = [directory URLByAppendingPathComponent:@"Library.frlibrary"];
    NSURL *copyURL = [directory URLByAppendingPathComponent:@"Copy.frlibrary"];
    FRDocument *document = [FRDocument new];
    FRDocument *loaded = nil;
    FRDocument *copy = nil;
    NSError *error = nil;
    @try {
        XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error], @"%@", error);
        BOOL saved = [document writeSafelyToURL:URL ofType:libraryType forSaveOperation:NSSaveOperation error:&error];
        XCTAssertTrue(saved, @"%@", error);
        if (!saved) return;
        [document close];
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[URL.path stringByAppendingPathComponent:@"Library.sqlite"]]);
        NSURL *assetsURL = [URL URLByAppendingPathComponent:@"assets" isDirectory:YES];
        XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:assetsURL withIntermediateDirectories:NO attributes:nil error:&error], @"%@", error);
        NSData *collectedBytes = [@"Collected attachment bytes: café, 日本語" dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertTrue([collectedBytes writeToURL:[assetsURL URLByAppendingPathComponent:@"Notes.txt"] options:NSDataWritingAtomic error:&error], @"%@", error);
        NSString *detectedType = [NSDocumentController.sharedDocumentController typeForContentsOfURL:URL error:&error];
        XCTAssertNotNil(detectedType, @"%@", error);
        if (!detectedType) return;
        UTType *type = [UTType typeWithIdentifier:detectedType];
        XCTAssertEqualObjects(type, [UTType typeWithIdentifier:libraryType]);
        XCTAssertTrue([type conformsToType:UTTypePackage]);
        XCTAssertTrue([type conformsToType:UTTypeContent]);
        loaded = [[FRDocument alloc] initWithContentsOfURL:URL ofType:detectedType error:&error];
        XCTAssertNotNil(loaded, @"%@", error);
        if (!loaded) return;
        XCTAssertTrue([loaded writeSafelyToURL:URL ofType:detectedType forSaveOperation:NSSaveOperation error:&error], @"%@", error);
        XCTAssertTrue([loaded writeSafelyToURL:copyURL ofType:detectedType forSaveOperation:NSSaveAsOperation error:&error], @"%@", error);
        [loaded close];
        for (NSURL *savedURL in @[URL, copyURL]) {
            XCTAssertEqualObjects([NSData dataWithContentsOfURL:[savedURL URLByAppendingPathComponent:@"assets/Notes.txt"]], collectedBytes);
        }
        copy = [[FRDocument alloc] initWithContentsOfURL:copyURL ofType:detectedType error:&error];
        XCTAssertNotNil(copy, @"%@", error);
    } @finally {
        [copy close];
        [loaded close];
        [document close];
        [NSFileManager.defaultManager removeItemAtURL:directory error:NULL];
    }
}

- (void)testInvalidPackageDoesNotReplaceAnOpenLibrary {
    FRDocument *document = [FRDocument new];
    NSError *error = nil;
    NSURL *foreignURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    @try {
        NSFileWrapper *original = [document fileWrapperOfType:@"dev.foliosuite.Research.Library" error:&error];
        XCTAssertNotNil(original, @"%@", error);
        if (!original) return;
        NSManagedObjectModel *foreignModel = [NSManagedObjectModel new];
        foreignModel.versionIdentifiers = [NSSet setWithObject:@"An unsupported future catalog"];
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:foreignModel];
        NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:foreignURL
            options:@{NSSQLitePragmasOption:@{@"journal_mode":@"DELETE"}} error:&error];
        XCTAssertNotNil(store, @"%@", error);
        if (!store) return;
        XCTAssertTrue([coordinator removePersistentStore:store error:&error], @"%@", error);
        NSData *foreignBytes = [NSData dataWithContentsOfURL:foreignURL];
        XCTAssertNotNil(foreignBytes);
        if (!foreignBytes) return;
        NSData *invalidBytes = [@"Not a SQLite database" dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableArray<NSDictionary *> *invalidMembers = [NSMutableArray arrayWithArray:@[
            @{},
            @{@"Library.sqlite":[[NSFileWrapper alloc] initRegularFileWithContents:invalidBytes]},
            @{@"Library.sqlite":[[NSFileWrapper alloc] initRegularFileWithContents:foreignBytes]}
        ]];
        for (NSString *sidecar in @[@"Library.sqlite-wal", @"Library.sqlite-shm", @"Library.sqlite-journal"]) {
            NSMutableDictionary *members = [original.fileWrappers mutableCopy];
            members[sidecar] = [[NSFileWrapper alloc] initRegularFileWithContents:NSData.data];
            [invalidMembers addObject:members];
        }
        for (NSDictionary *members in invalidMembers) {
            error = nil;
            NSFileWrapper *invalid = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:members];
            XCTAssertFalse([document readFromFileWrapper:invalid ofType:@"dev.foliosuite.Research.Library" error:&error]);
            XCTAssertNotNil(error);
            XCTAssertEqual([document fileWrapperOfType:@"dev.foliosuite.Research.Library" error:NULL], original);
        }
    } @finally {
        [document close];
        [NSFileManager.defaultManager removeItemAtURL:foreignURL error:NULL];
    }
}
@end
