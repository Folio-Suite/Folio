// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FRLibraryPackage.h"
#import <CoreData/CoreData.h>
#import <FolioKit/FolioKit.h>

static NSError *FRPackageError(NSString *reason) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                          userInfo:@{NSLocalizedDescriptionKey:@"Research cannot read this Source Library.",
                                     NSLocalizedRecoverySuggestionErrorKey:reason}];
}

// Frozen empty shell model. A future source catalog needs its own model version.
static NSManagedObjectModel *FRLibraryModel(void) {
    NSManagedObjectModel *model = [NSManagedObjectModel new];
    model.versionIdentifiers = [NSSet setWithObject:@"FolioResearchLibraryShellV1"];
    return model;
}

@implementation FRLibraryPackage
+ (NSFileWrapper *)emptyPackageWithError:(NSError **)error {
    return [FKPackageSupport withTemporaryDirectoryWithError:error operation:^id(NSURL *directory, NSError **error) {
        NSURL *URL = [directory URLByAppendingPathComponent:@"Library.sqlite"];
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:FRLibraryModel()];
        NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:URL
            options:@{NSSQLitePragmasOption:@{@"journal_mode":@"DELETE"}} error:error];
        if (!store) return nil;
        if (![coordinator removePersistentStore:store error:error]) return nil;
        NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:error];
        return data ? [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{
            @"Library.sqlite":[[NSFileWrapper alloc] initRegularFileWithContents:data]
        }] : nil;
    }];
}

+ (BOOL)validatePackage:(NSFileWrapper *)package error:(NSError **)error {
    NSDictionary<NSString *, NSFileWrapper *> *members = package.isDirectory ? package.fileWrappers : nil;
    NSFileWrapper *database = members[@"Library.sqlite"];
    if (!database.isRegularFile || members[@"Library.sqlite-wal"] || members[@"Library.sqlite-shm"] || members[@"Library.sqlite-journal"]) {
        if (error) *error = FRPackageError(@"Expected a package containing a closed Library.sqlite snapshot. Live database sidecars are not supported by this shell.");
        return NO;
    }
    return [FKPackageSupport withTemporaryDirectoryWithError:error operation:^id(NSURL *directory, NSError **error) {
        NSURL *URL = [directory URLByAppendingPathComponent:@"Library.sqlite"];
        if (![database writeToURL:URL options:NSFileWrapperWritingAtomic originalContentsURL:nil error:error]) return nil;
        NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:URL options:nil error:error];
        if (!metadata) return nil;
        NSManagedObjectModel *model = FRLibraryModel();
        NSSet *versions = [NSSet setWithArray:metadata[NSStoreModelVersionIdentifiersKey] ?: @[]];
        if (![versions isEqual:model.versionIdentifiers] || ![model isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
            if (error) *error = FRPackageError(@"This Source Library uses a different catalog model. Open it with a compatible version of Research.");
            return nil;
        }
        return @YES;
    }] != nil;
}
@end
