// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

@class FKText;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const FWWorkDocumentType;

/// A first authoring slice: a Work with one Content Unit placed in its Manuscript.
/// Immutable text snapshots keep the persistence boundary independent of the editor.
@interface FWWork : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *manuscriptIdentifier;
@property (nonatomic, strong) FKText *text;
- (nullable instancetype)initWithFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)error;
- (nullable NSFileWrapper *)fileWrapperWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
