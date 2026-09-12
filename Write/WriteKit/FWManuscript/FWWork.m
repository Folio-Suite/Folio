// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWWork.h"
#import "FWWorkStore.h"
#import <FolioKit/FolioKit.h>

NSString * const FWWorkDocumentType = @"dev.foliosuite.Write.Work";

@implementation FWWork
- (instancetype)init {
    if ((self = [super init])) {
        _identifier = [FKIdentifiedObject new].identifier;
        _manuscript = [FKManuscript new];
    }
    return self;
}
- (instancetype)initWithFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)error {
    if ((self = [super init])) {
        NSDictionary *snapshot = [FWWorkStore readPackage:wrapper error:error];
        if (!snapshot) return nil;
        _identifier = [snapshot[@"workIdentifier"] copy];
        _manuscript = snapshot[@"manuscript"];
    }
    return self;
}
- (NSString *)manuscriptIdentifier { return self.manuscript.identifier; }
- (FKText *)text { return self.manuscript.units.firstObject; }
- (void)setText:(FKText *)text {
    NSMutableArray *units = [self.manuscript.units mutableCopy];
    units[0] = text;
    self.manuscript = [[FKManuscript alloc] initWithIdentifier:self.manuscriptIdentifier units:units];
}
- (FKText *)textWithIdentifier:(NSString *)identifier {
    for (FKText *unit in self.manuscript.units) if ([unit.identifier isEqual:identifier]) return unit;
    return nil;
}
- (void)replaceText:(FKText *)text {
    NSMutableArray *units = [self.manuscript.units mutableCopy];
    NSUInteger index = [units indexOfObjectPassingTest:^BOOL(FKText *unit, NSUInteger index, BOOL *stop) {
        return [unit.identifier isEqual:text.identifier];
    }];
    NSParameterAssert(index != NSNotFound);
    units[index] = text;
    self.manuscript = [[FKManuscript alloc] initWithIdentifier:self.manuscriptIdentifier units:units];
}
- (NSFileWrapper *)fileWrapperWithError:(NSError **)error {
    return [FWWorkStore packageWithWorkIdentifier:self.identifier
                            manuscript:self.manuscript error:error];
}
@end
