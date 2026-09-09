#import "FWWorkStore.h"
#import <CoreData/CoreData.h>
#import <FolioKit/FolioKit.h>

static NSError *FWStoreError(NSString *reason) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                          userInfo:@{NSLocalizedDescriptionKey:@"Write cannot read this Work package.",
                                     NSLocalizedRecoverySuggestionErrorKey:reason}];
}

static NSAttributeDescription *FWAttribute(NSString *name, NSAttributeType type) {
    NSAttributeDescription *attribute = [NSAttributeDescription new];
    attribute.name = name;
    attribute.attributeType = type;
    attribute.optional = NO;
    return attribute;
}

static void FWRelationship(NSEntityDescription *owner, NSString *name, NSEntityDescription *child, NSString *inverseName, BOOL many) {
    NSRelationshipDescription *relationship = [NSRelationshipDescription new];
    relationship.name = name;
    relationship.destinationEntity = child;
    relationship.maxCount = many ? 0 : 1;
    relationship.deleteRule = NSCascadeDeleteRule;
    relationship.optional = NO;
    NSRelationshipDescription *inverse = [NSRelationshipDescription new];
    inverse.name = inverseName;
    inverse.destinationEntity = owner;
    inverse.maxCount = 1;
    inverse.optional = NO;
    inverse.deleteRule = NSNullifyDeleteRule;
    relationship.inverseRelationship = inverse;
    inverse.inverseRelationship = relationship;
    owner.properties = [owner.properties arrayByAddingObject:relationship];
    child.properties = [child.properties arrayByAddingObject:inverse];
}

/// Frozen v1 model. Future migrations must retain this definition and add a new version.
static NSManagedObjectModel *FWStoreModelV1(void) {
    NSManagedObjectModel *model = [NSManagedObjectModel new];
    NSMutableDictionary<NSString *, NSEntityDescription *> *entities = [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *attributes = @{
        @"Work":@{@"identifier":@(NSStringAttributeType), @"formatVersion":@(NSInteger16AttributeType)},
        @"Manuscript":@{@"identifier":@(NSStringAttributeType)},
        @"ContentUnit":@{@"identifier":@(NSStringAttributeType)},
        @"Paragraph":@{@"identifier":@(NSStringAttributeType), @"position":@(NSInteger64AttributeType), @"alignment":@(NSInteger16AttributeType)},
        @"Run":@{@"position":@(NSInteger64AttributeType), @"text":@(NSStringAttributeType), @"meaning":@(NSInteger16AttributeType), @"appearance":@(NSInteger16AttributeType)}
    };
    for (NSString *name in [[attributes allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSEntityDescription *entity = [NSEntityDescription new];
        entity.name = name;
        entity.managedObjectClassName = @"NSManagedObject";
        NSMutableArray *properties = [NSMutableArray array];
        for (NSString *key in [[attributes[name] allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            [properties addObject:FWAttribute(key, [attributes[name][key] unsignedIntegerValue])];
        }
        entity.properties = properties;
        entities[name] = entity;
    }
    FWRelationship(entities[@"Work"], @"units", entities[@"ContentUnit"], @"work", YES);
    FWRelationship(entities[@"Work"], @"manuscript", entities[@"Manuscript"], @"work", NO);
    FWRelationship(entities[@"ContentUnit"], @"paragraphs", entities[@"Paragraph"], @"unit", YES);
    FWRelationship(entities[@"Paragraph"], @"runs", entities[@"Run"], @"paragraph", YES);
    // Placement is a reference; ownership remains with Work, not Manuscript.
    NSRelationshipDescription *placement = [NSRelationshipDescription new];
    placement.name = @"contentUnit";
    placement.destinationEntity = entities[@"ContentUnit"];
    placement.maxCount = 1;
    placement.optional = NO;
    placement.deleteRule = NSNullifyDeleteRule;
    entities[@"Manuscript"].properties = [entities[@"Manuscript"].properties arrayByAddingObject:placement];
    model.entities = [entities objectsForKeys:[[entities allKeys] sortedArrayUsingSelector:@selector(compare:)] notFoundMarker:NSNull.null];
    model.versionIdentifiers = [NSSet setWithObject:@"FolioWriteWorkV1"];
    return model;
}

static NSManagedObject *FWInsert(NSManagedObjectContext *context, NSString *entity, NSDictionary *values) {
    NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:entity inManagedObjectContext:context];
    [object setValuesForKeysWithDictionary:values];
    return object;
}

static NSArray<NSManagedObject *> *FWOrdered(NSSet<NSManagedObject *> *objects) {
    return [objects.allObjects sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"position" ascending:YES]]];
}

static BOOL FWUniqueIdentifier(NSString *identifier, NSMutableSet<NSString *> *seen) {
    if (![identifier isKindOfClass:NSString.class] || identifier.length == 0 || [seen containsObject:identifier]) return NO;
    [seen addObject:identifier];
    return YES;
}

@implementation FWWorkStore

+ (id)withTemporaryStore:(NSFileWrapper *)package writing:(BOOL)writing error:(NSError **)error
                  block:(id (^)(NSManagedObjectContext *, NSError **))block {
    return [FKPackageSupport withTemporaryDirectoryWithError:error operation:^id(NSURL *directory, NSError **error) {
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:FWStoreModelV1()];
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
        NSManagedObject *unit = units.count == 1 ? units.anyObject : nil;
        NSMutableSet *identifiers = [NSMutableSet set];
        BOOL valid = work && [[work valueForKey:@"formatVersion"] isEqual:@1] && manuscript && unit &&
                     [[manuscript valueForKey:@"contentUnit"] isEqual:unit] &&
                     FWUniqueIdentifier([work valueForKey:@"identifier"], identifiers) &&
                     FWUniqueIdentifier([manuscript valueForKey:@"identifier"], identifiers) &&
                     FWUniqueIdentifier([unit valueForKey:@"identifier"], identifiers);
        NSMutableArray *paragraphs = [NSMutableArray array];
        NSUInteger runCount = 0;
        for (NSManagedObject *p in FWOrdered([unit valueForKey:@"paragraphs"])) {
            NSInteger alignment = [[p valueForKey:@"alignment"] integerValue];
            valid &= FWUniqueIdentifier([p valueForKey:@"identifier"], identifiers) &&
                     [[p valueForKey:@"position"] unsignedIntegerValue] == paragraphs.count &&
                     alignment >= FKParagraphAlignmentNatural && alignment <= FKParagraphAlignmentJustified;
            NSMutableArray *runs = [NSMutableArray array];
            for (NSManagedObject *r in FWOrdered([p valueForKey:@"runs"])) {
                NSUInteger meaning = [[r valueForKey:@"meaning"] unsignedIntegerValue];
                NSUInteger appearance = [[r valueForKey:@"appearance"] unsignedIntegerValue];
                NSString *string = [r valueForKey:@"text"];
                valid &= [[r valueForKey:@"position"] unsignedIntegerValue] == runs.count &&
                         !(meaning & ~(FKTextMeaningEmphasis | FKTextMeaningStrongEmphasis)) &&
                         !(appearance & ~(FKTextAppearanceBold | FKTextAppearanceItalic)) && string &&
                         [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n\u2029"]].location == NSNotFound;
                if (!valid) break;
                [runs addObject:[[FKTextRun alloc] initWithString:string meaning:meaning appearance:appearance]];
            }
            if (!valid) break;
            runCount += runs.count;
            [paragraphs addObject:[[FKParagraph alloc] initWithIdentifier:[p valueForKey:@"identifier"] runs:runs alignment:alignment]];
        }
        NSDictionary *expectedCounts = @{@"Work":@1, @"Manuscript":@1, @"ContentUnit":@1, @"Paragraph":@(paragraphs.count), @"Run":@(runCount)};
        for (NSString *entity in expectedCounts) {
            NSUInteger count = [context countForFetchRequest:[NSFetchRequest fetchRequestWithEntityName:entity] error:readError];
            valid &= count == [expectedCounts[entity] unsignedIntegerValue];
        }
        if (!valid || !paragraphs.count) {
            if (readError && !*readError) *readError = FWStoreError(@"This editor supports one Content Unit and its Manuscript placement. The store contains invalid or unsupported structure; no content has been changed.");
            return nil;
        }
        return @{@"workIdentifier":[work valueForKey:@"identifier"],
                 @"manuscriptIdentifier":[manuscript valueForKey:@"identifier"],
                 @"text":[[FKText alloc] initWithIdentifier:[unit valueForKey:@"identifier"] paragraphs:paragraphs]};
    }];
}

+ (NSFileWrapper *)packageWithWorkIdentifier:(NSString *)identifier manuscriptIdentifier:(NSString *)manuscriptIdentifier text:(FKText *)text error:(NSError **)error {
    NSFileWrapper *package = [self withTemporaryStore:nil writing:YES error:error block:^id(NSManagedObjectContext *context, NSError **writeError) {
        NSManagedObject *work = FWInsert(context, @"Work", @{@"identifier":identifier, @"formatVersion":@1});
        NSManagedObject *unit = FWInsert(context, @"ContentUnit", @{@"identifier":text.identifier, @"work":work});
        FWInsert(context, @"Manuscript", @{@"identifier":manuscriptIdentifier, @"work":work, @"contentUnit":unit});
        NSUInteger paragraphIndex = 0;
        for (FKParagraph *paragraph in text.paragraphs) {
            NSManagedObject *p = FWInsert(context, @"Paragraph", @{@"identifier":paragraph.identifier,
                @"position":@(paragraphIndex++), @"alignment":@(paragraph.alignment), @"unit":unit});
            NSUInteger runIndex = 0;
            for (FKTextRun *run in paragraph.runs) FWInsert(context, @"Run", @{@"text":run.string,
                @"meaning":@(run.meaning), @"appearance":@(run.appearance), @"position":@(runIndex++), @"paragraph":p});
        }
        return [context save:writeError] ? @YES : nil;
    }];
    // Refuse a save that this reader cannot reconstruct; the old package stays intact.
    if (!package) return nil;
    FKText *loaded = [self readPackage:package error:error][@"text"];
    BOOL equal = [loaded.identifier isEqual:text.identifier] && loaded.paragraphs.count == text.paragraphs.count;
    for (NSUInteger i = 0; equal && i < text.paragraphs.count; i++) {
        FKParagraph *before = text.paragraphs[i], *after = loaded.paragraphs[i];
        equal = [before.identifier isEqual:after.identifier] && before.alignment == after.alignment && before.runs.count == after.runs.count;
        for (NSUInteger j = 0; equal && j < before.runs.count; j++) {
            FKTextRun *a = before.runs[j], *b = after.runs[j];
            equal = [a.string isEqual:b.string] && a.meaning == b.meaning && a.appearance == b.appearance;
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
