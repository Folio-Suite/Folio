#import <Foundation/Foundation.h>
@class FKText;

NS_ASSUME_NONNULL_BEGIN

/// Private Core Data boundary. NSDocument owns atomic package replacement.
@interface FWWorkStore : NSObject
+ (nullable NSDictionary *)readPackage:(NSFileWrapper *)package error:(NSError **)error;
+ (nullable NSFileWrapper *)packageWithWorkIdentifier:(NSString *)identifier
                               manuscriptIdentifier:(NSString *)manuscriptIdentifier
                                               text:(FKText *)text error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
