// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

@class FKText, FKManuscript;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const FWWorkDocumentType;

/// A Work with a flat, ordered Manuscript of text Content Units.
/// Access and mutation are confined to the main thread.
/// Immutable text snapshots keep the persistence boundary independent of the editor.
@interface FWWork : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *manuscriptIdentifier;
/// Immutable Manuscript snapshot. Replacements must retain its identity.
@property (nonatomic, strong) FKManuscript *manuscript;
/// Convenience access to the first unit, independent of editor selection.
/// Assigning replaces the first unit; prefer identity-based replacement in editors.
@property (nonatomic, strong) FKText *text;
/// Finds a placed Content Unit by stable identity, or returns nil.
- (nullable FKText *)textWithIdentifier:(NSString *)identifier;
/// Replaces the matching unit without changing its position. Requires an existing identity.
- (void)replaceText:(FKText *)text;
- (nullable instancetype)initWithFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)error;
- (nullable NSFileWrapper *)fileWrapperWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
