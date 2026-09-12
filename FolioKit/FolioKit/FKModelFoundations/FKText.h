// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stable identity shared by authored objects. Numbering and display labels are separate.
@interface FKIdentifiedObject : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;
@end

/// One semantic emphasis category per run. Mixed selections are an editor state.
/// Renderers may choose a different visual idiom; font traits do not define meaning.
typedef NS_ENUM(NSUInteger, FKTextEmphasis) {
    FKTextEmphasisNone = 0,
    FKTextEmphasisEmphasis = 1,
    FKTextEmphasisStrongEmphasis = 2,
    /// Emphasis rendered with both bold and italic in the starter editor.
    FKTextEmphasisVeryStrongEmphasis = 3,
};

/// Immutable, independent visual choices. These values never imply semantic meaning.
@interface FKTextPresentation : NSObject
/// Explicit bold font styling.
@property (nonatomic, readonly) BOOL bold;
/// Explicit italic font styling.
@property (nonatomic, readonly) BOOL italic;
/// A single line beneath retained text.
@property (nonatomic, readonly) BOOL underline;
/// A single line through retained text, independent of Proposed Revisions.
@property (nonatomic, readonly) BOOL strikethrough;
/// Creates a presentation with all four choices disabled.
- (instancetype)init;
/// Creates independently combinable presentation choices.
- (instancetype)initWithBold:(BOOL)bold italic:(BOOL)italic underline:(BOOL)underline
              strikethrough:(BOOL)strikethrough NS_DESIGNATED_INITIALIZER;
@end

typedef NS_ENUM(NSUInteger, FKParagraphAlignment) {
    FKParagraphAlignmentNatural,
    FKParagraphAlignmentLeft,
    FKParagraphAlignmentCenter,
    FKParagraphAlignmentRight,
    FKParagraphAlignmentJustified,
};

/// An immutable span. Meaning never has to be inferred from its rendered font.
@interface FKTextRun : NSObject
@property (nonatomic, copy, readonly) NSString *string;
/// The single authored emphasis category; never inferred from presentation.
@property (nonatomic, readonly) FKTextEmphasis emphasis;
/// Explicit presentation choices, retained independently of semantic emphasis.
@property (nonatomic, strong, readonly) FKTextPresentation *presentation;
- (instancetype)initWithString:(NSString *)string
                       emphasis:(FKTextEmphasis)emphasis
                    presentation:(FKTextPresentation *)presentation NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FKParagraph : FKIdentifiedObject
@property (nonatomic, copy, readonly) NSArray<FKTextRun *> *runs;
@property (nonatomic, readonly) FKParagraphAlignment alignment;
@property (nonatomic, copy, readonly) NSString *string;
- (instancetype)initWithIdentifier:(NSString *)identifier
                              runs:(NSArray<FKTextRun *> *)runs
                         alignment:(FKParagraphAlignment)alignment;
@end

/// Immutable authored text, reusable by Write and Research without AppKit attributes.
@interface FKText : FKIdentifiedObject
/// A display title for this text Content Unit; independent of its authored words.
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSArray<FKParagraph *> *paragraphs;
/// Whether this Content Unit's presentation/emphasis warning has been dismissed.
/// Preserved across edits and native save/reopen; never copied with pasted text.
@property (nonatomic, readonly) BOOL formattingWarningDismissed;
@property (nonatomic, copy, readonly) NSString *string;
- (instancetype)initWithIdentifier:(NSString *)identifier paragraphs:(NSArray<FKParagraph *> *)paragraphs;
/// Restores a Content Unit snapshot, including its persistent warning preference.
- (instancetype)initWithIdentifier:(NSString *)identifier paragraphs:(NSArray<FKParagraph *> *)paragraphs
        formattingWarningDismissed:(BOOL)dismissed;
/// Restores all text Content Unit fields. The title may be empty; identity must be stable.
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title
                        paragraphs:(NSArray<FKParagraph *> *)paragraphs formattingWarningDismissed:(BOOL)dismissed;
@end

/// Immutable primary arrangement of text Content Units, independent of editor selection.
/// This initial flat Manuscript requires at least one unit and unique unit identities.
@interface FKManuscript : FKIdentifiedObject
/// Content Units in reading order. No UI state or editor references are retained.
@property (nonatomic, copy, readonly) NSArray<FKText *> *units;
/// Creates a snapshot; callers retain identity across reorderings and text replacements.
- (instancetype)initWithIdentifier:(NSString *)identifier units:(NSArray<FKText *> *)units;
@end

NS_ASSUME_NONNULL_END
