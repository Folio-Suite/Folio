#import "FKPackageSupport.h"

@implementation FKPackageSupport
+ (id)withTemporaryDirectoryWithError:(NSError **)error
                          operation:(id (^)(NSURL *, NSError **))operation {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    if (![manager createDirectoryAtURL:directory withIntermediateDirectories:NO attributes:nil error:error]) return nil;
    @try {
        return operation(directory, error);
    } @finally {
        [manager removeItemAtURL:directory error:NULL];
    }
}
@end
