// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
@class FKManuscript;

NS_ASSUME_NONNULL_BEGIN

/// Private Core Data boundary. NSDocument owns atomic package replacement.
@interface FWWorkStore : NSObject
+ (nullable NSDictionary *)readPackage:(NSFileWrapper *)package error:(NSError **)error;
+ (nullable NSFileWrapper *)packageWithWorkIdentifier:(NSString *)identifier
                               manuscript:(FKManuscript *)manuscript error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
