// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Stable identity shared by authored objects. Numbering and display labels are separate.
@interface FKIdentifiedObject : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;
@end

typedef NS_OPTIONS(NSUInteger, FKTextMeaning) {
    FKTextMeaningNone = 0,
    FKTextMeaningEmphasis = 1 << 0,
    FKTextMeaningStrongEmphasis = 1 << 1,
};

typedef NS_OPTIONS(NSUInteger, FKTextAppearance) {
    FKTextAppearancePlain = 0,
    FKTextAppearanceBold = 1 << 0,
    FKTextAppearanceItalic = 1 << 1,
};

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
@property (nonatomic, readonly) FKTextMeaning meaning;
@property (nonatomic, readonly) FKTextAppearance appearance;
- (instancetype)initWithString:(NSString *)string
                       meaning:(FKTextMeaning)meaning
                    appearance:(FKTextAppearance)appearance NS_DESIGNATED_INITIALIZER;
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
@property (nonatomic, copy, readonly) NSArray<FKParagraph *> *paragraphs;
@property (nonatomic, copy, readonly) NSString *string;
- (instancetype)initWithIdentifier:(NSString *)identifier paragraphs:(NSArray<FKParagraph *> *)paragraphs;
@end

NS_ASSUME_NONNULL_END
