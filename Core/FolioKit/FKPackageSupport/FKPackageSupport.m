// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FKPackageSupport.h"
#import <FolioKit/FolioKit-Swift.h>

@implementation FKPackageSupport
+ (id)withTemporaryDirectoryWithError:(NSError **)error
                          operation:(id (^)(NSURL *, NSError **))operation {
    NSURL *directory = [FKSwiftStagingBridge createAndReturnError:error];
    if (!directory) return nil;
    @try {
        return operation(directory, error);
    } @finally {
        [FKSwiftStagingBridge remove:directory];
    }
}
@end
