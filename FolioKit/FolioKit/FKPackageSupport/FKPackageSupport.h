// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Common staging facilities for native packages, independent of domain schemas.
@interface FKPackageSupport : NSObject
/// Runs the operation synchronously in a unique temporary directory and removes it
/// on success, failure, or exception. The result must not depend on files remaining
/// in that directory. The operation returns nil and sets error when it fails.
+ (nullable id)withTemporaryDirectoryWithError:(NSError **)error
                                  operation:(id _Nullable (^)(NSURL *directory, NSError **error))operation;
@end

NS_ASSUME_NONNULL_END
