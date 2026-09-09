#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Native package support for the empty Research shell. Source catalog editing is
/// not implemented yet; existing package members are retained when saving.
@interface FRLibraryPackage : NSObject
+ (nullable NSFileWrapper *)emptyPackageWithError:(NSError **)error;
+ (BOOL)validatePackage:(NSFileWrapper *)package error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
