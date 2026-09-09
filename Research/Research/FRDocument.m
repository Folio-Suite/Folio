#import "FRDocument.h"
#import <ResearchKit/ResearchKit.h>

@interface FRDocument ()
@property (nonatomic, strong) NSFileWrapper *libraryPackage;
@end

@implementation FRDocument
+ (BOOL)autosavesInPlace { return YES; }

- (void)makeWindowControllers {
    [self addWindowController:[[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"]];
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    if (!self.libraryPackage) self.libraryPackage = [FRLibraryPackage emptyPackageWithError:outError];
    return self.libraryPackage;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError **)outError {
    if (![FRLibraryPackage validatePackage:fileWrapper error:outError]) return NO;
    self.libraryPackage = fileWrapper;
    return YES;
}
@end
