#import "FWWork.h"
#import "FWWorkStore.h"
#import <FolioKit/FolioKit.h>

NSString * const FWWorkDocumentType = @"dev.foliosuite.Write.Work";

@implementation FWWork
- (instancetype)init {
    if ((self = [super init])) {
        _identifier = [FKIdentifiedObject new].identifier;
        _manuscriptIdentifier = [FKIdentifiedObject new].identifier;
        _text = [FKText new];
    }
    return self;
}
- (instancetype)initWithFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)error {
    if ((self = [super init])) {
        NSDictionary *snapshot = [FWWorkStore readPackage:wrapper error:error];
        if (!snapshot) return nil;
        _identifier = [snapshot[@"workIdentifier"] copy];
        _manuscriptIdentifier = [snapshot[@"manuscriptIdentifier"] copy];
        _text = snapshot[@"text"];
    }
    return self;
}
- (NSFileWrapper *)fileWrapperWithError:(NSError **)error {
    return [FWWorkStore packageWithWorkIdentifier:self.identifier
                            manuscriptIdentifier:self.manuscriptIdentifier text:self.text error:error];
}
@end
