// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWWorkStore.h"
#import <CoreData/CoreData.h>
#import <FolioKit/FolioKit.h>

static NSError *FWStoreError(NSString *reason) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                          userInfo:@{NSLocalizedDescriptionKey:@"Write cannot read this Work package.",
                                     NSLocalizedRecoverySuggestionErrorKey:reason}];
}

// The versioned model in WriteKit is the sole schema definition. Keep Core Data
// entities and contexts private; callers continue using immutable text snapshots.
static NSManagedObjectModel *FWStoreModel(NSError **error) {
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"];
    NSURL *url = [bundle URLForResource:@"FWWork" withExtension:@"momd"];
    NSManagedObjectModel *model = url ? [[NSManagedObjectModel alloc] initWithContentsOfURL:url] : nil;
    if (!model && error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError
            userInfo:@{NSLocalizedDescriptionKey:@"WriteKit’s data model could not be loaded.",
                       NSLocalizedRecoverySuggestionErrorKey:@"Rebuild or reinstall the application with its FWWork model resource."}];
    }
    return model;
}

static NSManagedObject *FWInsert(NSManagedObjectContext *context, NSString *entity, NSDictionary *values) {
    NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:context];
    [object setValuesForKeysWithDictionary:values];
    return object;
}

static BOOL FWUniqueIdentifier(NSString *identifier, NSMutableSet<NSString *> *seen) {
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0 || [seen containsObject:identifier]) return NO;
    [seen addObject:identifier];
    return YES;
}

@implementation FWWorkStore

+ (id)withTemporaryStore:(NSFileWrapper *)package writing:(BOOL)writing error:(NSError **)error
                  block:(id (^)(NSManagedObjectContext *, NSError **))block {
    NSManagedObjectModel *model = FWStoreModel(error);
    if (!model) return nil;
    return [FKPackageSupport withTemporaryDirectoryWithError:error operation:^id(NSURL *directory, NSError **error) {
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        NSPersistentStore *store = nil;
        @try {
            NSURL *storeURL = [directory URLByAppendingPathComponent:@"Work.sqlite"];
            if (!writing) {
                NSDictionary *files = package.isDirectory ? package.fileWrappers : nil;
                NSFileWrapper *file = files[@"Work.sqlite"];
                if (files.count != 1 || !file.isRegularFile) {
                    if (error) *error = FWStoreError(@"Expected a native Work package containing Work.sqlite. Extra files and unfamiliar formats are left untouched.");
                    return nil;
                }
                if (![file writeToURL:storeURL options:NSFileWrapperWritingAtomic originalContentsURL:nil error:error]) return nil;
                NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeURL options:nil error:error];
                if (!metadata) return nil;
                if (![coordinator.managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
                    if (error) *error = FWStoreError(@"This Work uses a different model version. Open it with a compatible version of Write.");
                    return nil;
                }
            }
            NSDictionary *options = @{NSReadOnlyPersistentStoreOption:@(!writing),
                                      NSSQLitePragmasOption:@{@"journal_mode":@"DELETE"}};
            store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:error];
            if (!store) return nil;
            NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            context.persistentStoreCoordinator = coordinator;
            __block id result;
            __block NSError *operationError;
            [context performBlockAndWait:^{ result = block(context, &operationError); }];
            if (operationError) {
                if (error) *error = operationError;
                return nil;
            }
            if (![coordinator removePersistentStore:store error:error]) return nil;
            store = nil;
            if (writing && result) {
                NSData *data = [NSData dataWithContentsOfURL:storeURL options:0 error:error];
                return data ? [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"Work.sqlite":[[NSFileWrapper alloc] initRegularFileWithContents:data]}] : nil;
            }
            return result;
        } @finally {
            if (store) [coordinator removePersistentStore:store error:NULL];
        }
    }];
}

+ (NSDictionary *)readPackage:(NSFileWrapper *)package error:(NSError **)error {
    return [self withTemporaryStore:package writing:NO error:error block:^id(NSManagedObjectContext *context, NSError **readError) {
        NSArray *works = [context executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Work"] error:readError];
        if (!works) return nil;
        NSManagedObject *work = works.count == 1 ? works.firstObject : nil;
        NSManagedObject *manuscript = [work valueForKey:@"manuscript"];
        NSSet *units = [work valueForKey:@"units"];
        NSArray *orderedUnits = [(NSOrderedSet *)[manuscript valueForKey:@"contentUnits"] array];
        NSMutableSet *identifiers = [NSMutableSet set];
        BOOL valid = work && [[work valueForKey:@"formatVersion"] isEqual:@1] && manuscript && units.count > 0 &&
                     [[NSSet setWithArray:orderedUnits] isEqual:units] &&
                     FWUniqueIdentifier([work valueForKey:@"identifier"], identifiers) &&
                     FWUniqueIdentifier([manuscript valueForKey:@"identifier"], identifiers);
        NSMutableArray *texts = [NSMutableArray array];
        NSUInteger runCount = 0, paragraphCount = 0;
        for (NSManagedObject *unit in orderedUnits) {
            valid &= FWUniqueIdentifier([unit valueForKey:@"identifier"], identifiers) && [unit valueForKey:@"title"] != nil;
            NSMutableArray *paragraphs = [NSMutableArray array];
            for (NSManagedObject *p in [(NSOrderedSet *)[unit valueForKey:@"paragraphs"] array]) {
                NSInteger alignment = [[p valueForKey:@"alignment"] integerValue];
                valid &= FWUniqueIdentifier([p valueForKey:@"identifier"], identifiers) &&
                         alignment >= FKParagraphAlignmentNatural && alignment <= FKParagraphAlignmentJustified;
                NSMutableArray *runs = [NSMutableArray array];
                for (NSManagedObject *r in [(NSOrderedSet *)[p valueForKey:@"runs"] array]) {
                    NSUInteger emphasis = [[r valueForKey:@"emphasis"] unsignedIntegerValue];
                    FKTextPresentation *presentation = [[FKTextPresentation alloc]
                        initWithBold:[[r valueForKey:@"bold"] boolValue] italic:[[r valueForKey:@"italic"] boolValue]
                        underline:[[r valueForKey:@"underline"] boolValue] strikethrough:[[r valueForKey:@"strikethrough"] boolValue]];
                    NSString *string = [r valueForKey:@"text"];
                    valid &= emphasis <= FKTextEmphasisVeryStrongEmphasis && string &&
                             [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n\u2029"]].location == NSNotFound;
                    if (!valid) break;
                    [runs addObject:[[FKTextRun alloc] initWithString:string emphasis:emphasis presentation:presentation]];
                }
                if (!valid) break;
                runCount += runs.count;
                [paragraphs addObject:[[FKParagraph alloc] initWithIdentifier:[p valueForKey:@"identifier"] runs:runs alignment:alignment]];
            }
            valid &= paragraphs.count > 0;
            if (!valid) break;
            paragraphCount += paragraphs.count;
            [texts addObject:[[FKText alloc] initWithIdentifier:[unit valueForKey:@"identifier"] title:[unit valueForKey:@"title"]
                paragraphs:paragraphs formattingWarningDismissed:[[unit valueForKey:@"formattingWarningDismissed"] boolValue]]];
        }
        NSDictionary *expectedCounts = @{@"Work":@1, @"Manuscript":@1, @"ContentUnit":@(texts.count), @"Paragraph":@(paragraphCount), @"Run":@(runCount)};
        for (NSString *entity in expectedCounts) {
            NSUInteger count = [context countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:entity] error:readError];
            valid &= count == [expectedCounts[entity] unsignedIntegerValue];
        }
        if (!valid || !texts.count) {
            if (readError && !*readError) *readError = FWStoreError(@"The store contains invalid or unsupported Manuscript structure; no content has been changed.");
            return nil;
        }
        return @{@"workIdentifier":[work valueForKey:@"identifier"],
                 @"manuscript":[[FKManuscript alloc] initWithIdentifier:[manuscript valueForKey:@"identifier"] units:texts]};
    }];
}

+ (NSFileWrapper *)packageWithWorkIdentifier:(NSString *)identifier manuscript:(FKManuscript *)manuscript error:(NSError **)error {
    NSFileWrapper *package = [self withTemporaryStore:nil writing:YES error:error block:^id(NSManagedObjectContext *context, NSError **writeError) {
        NSManagedObject *work = FWInsert(context, @"Work", @{@"identifier":identifier, @"formatVersion":@1});
        NSManagedObject *storedManuscript = FWInsert(context, @"Manuscript", @{@"identifier":manuscript.identifier, @"work":work});
        NSMutableArray *storedUnits = [NSMutableArray array];
        for (FKText *text in manuscript.units) {
            NSManagedObject *unit = FWInsert(context, @"ContentUnit", @{@"identifier":text.identifier, @"title":text.title, @"work":work, @"formattingWarningDismissed":@(text.formattingWarningDismissed)});
            [storedUnits addObject:unit];
            NSMutableArray<NSManagedObject *> *storedParagraphs = [NSMutableArray array];
            for (FKParagraph *paragraph in text.paragraphs) {
                NSManagedObject *p = FWInsert(context, @"Paragraph", @{@"identifier":paragraph.identifier,
                    @"alignment":@(paragraph.alignment), @"unit":unit});
                NSMutableArray<NSManagedObject *> *storedRuns = [NSMutableArray array];
                for (FKTextRun *run in paragraph.runs) [storedRuns addObject:FWInsert(context, @"Run", @{@"text":run.string,
                    @"emphasis":@(run.emphasis), @"bold":@(run.presentation.bold), @"italic":@(run.presentation.italic),
                    @"underline":@(run.presentation.underline), @"strikethrough":@(run.presentation.strikethrough), @"paragraph":p})];
                [p setValue:[NSOrderedSet orderedSetWithArray:storedRuns] forKey:@"runs"];
                [storedParagraphs addObject:p];
            }
            [unit setValue:[NSOrderedSet orderedSetWithArray:storedParagraphs] forKey:@"paragraphs"];
        }
        [storedManuscript setValue:[NSOrderedSet orderedSetWithArray:storedUnits] forKey:@"contentUnits"];
        return [context save:writeError] ? @YES : nil;
    }];
    // Refuse a save that this reader cannot reconstruct; the old package stays intact.
    if (!package) return nil;
    NSDictionary *snapshot = [self readPackage:package error:error];
    FKManuscript *loadedManuscript = snapshot[@"manuscript"];
    BOOL equal = [snapshot[@"workIdentifier"] isEqual:identifier] && [loadedManuscript.identifier isEqual:manuscript.identifier] && loadedManuscript.units.count == manuscript.units.count;
    for (NSUInteger unitIndex = 0; equal && unitIndex < manuscript.units.count; unitIndex++) {
        FKText *text = manuscript.units[unitIndex], *loaded = loadedManuscript.units[unitIndex];
        equal = [loaded.title isEqual:text.title] && [loaded.identifier isEqual:text.identifier] && loaded.paragraphs.count == text.paragraphs.count && loaded.formattingWarningDismissed == text.formattingWarningDismissed;
        for (NSUInteger i = 0; equal && i < text.paragraphs.count; i++) {
            FKParagraph *before = text.paragraphs[i], *after = loaded.paragraphs[i];
            equal = [before.identifier isEqual:after.identifier] && before.alignment == after.alignment && before.runs.count == after.runs.count;
            for (NSUInteger j = 0; equal && j < before.runs.count; j++) {
                FKTextRun *a = before.runs[j], *b = after.runs[j];
                equal = [a.string isEqual:b.string] && a.emphasis == b.emphasis && [a.presentation isEqual:b.presentation];
            }
        }
    }
    if (!equal) {
        if (error && !*error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError
            userInfo:@{NSLocalizedDescriptionKey:@"The Work could not be saved without losing information. The previous saved package has not been replaced."}];
        return nil;
    }
    return package;
}
@end
