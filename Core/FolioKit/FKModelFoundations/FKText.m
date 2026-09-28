// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FKText.h"

@implementation FKIdentifiedObject
- (instancetype)init {
    return [self initWithIdentifier:[@"o" stringByAppendingString:NSUUID.UUID.UUIDString.lowercaseString]];
}
- (instancetype)initWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier.length > 0);
    if ((self = [super init])) _identifier = [identifier copy];
    return self;
}
@end

@implementation FKTextPresentation
- (instancetype)init { return [self initWithBold:NO italic:NO underline:NO strikethrough:NO]; }
- (instancetype)initWithBold:(BOOL)bold italic:(BOOL)italic underline:(BOOL)underline strikethrough:(BOOL)strikethrough {
    if ((self = [super init])) {
        _bold = bold; _italic = italic; _underline = underline; _strikethrough = strikethrough;
    }
    return self;
}
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:FKTextPresentation.class]) return NO;
    FKTextPresentation *other = object;
    return self.bold == other.bold && self.italic == other.italic &&
        self.underline == other.underline && self.strikethrough == other.strikethrough;
}
- (NSUInteger)hash {
    return @[@(self.bold), @(self.italic), @(self.underline), @(self.strikethrough)].description.hash;
}
@end

@implementation FKTextRun
- (instancetype)initWithString:(NSString *)string emphasis:(FKTextEmphasis)emphasis presentation:(FKTextPresentation *)presentation {
    NSParameterAssert(string);
    NSParameterAssert(presentation);
    NSParameterAssert(emphasis <= FKTextEmphasisVeryStrongEmphasis);
    if ((self = [super init])) {
        _string = [string copy];
        _emphasis = emphasis;
        _presentation = presentation;
    }
    return self;
}
@end

@implementation FKParagraph
- (instancetype)initWithIdentifier:(NSString *)identifier {
    return [self initWithIdentifier:identifier runs:@[] alignment:FKParagraphAlignmentNatural];
}
- (instancetype)initWithIdentifier:(NSString *)identifier runs:(NSArray<FKTextRun *> *)runs alignment:(FKParagraphAlignment)alignment {
    NSParameterAssert(runs);
    if ((self = [super initWithIdentifier:identifier])) {
        _runs = [runs copy];
        _alignment = alignment;
    }
    return self;
}
- (NSString *)string {
    NSMutableString *result = [NSMutableString string];
    for (FKTextRun *run in self.runs) [result appendString:run.string];
    return result;
}
@end

@implementation FKText
- (instancetype)initWithIdentifier:(NSString *)identifier {
    return [self initWithIdentifier:identifier paragraphs:@[[FKParagraph new]]];
}
- (instancetype)initWithIdentifier:(NSString *)identifier paragraphs:(NSArray<FKParagraph *> *)paragraphs {
    return [self initWithIdentifier:identifier paragraphs:paragraphs formattingWarningDismissed:NO];
}
- (instancetype)initWithIdentifier:(NSString *)identifier paragraphs:(NSArray<FKParagraph *> *)paragraphs formattingWarningDismissed:(BOOL)dismissed {
    return [self initWithIdentifier:identifier title:NSLocalizedStringWithDefaultValue(@"content-unit.default-title", @"Localizable", [NSBundle bundleWithIdentifier:@"dev.foliosuite.FolioKit"], @"Untitled", @"Initial title of a newly created Content Unit. Stored as authored content at creation; never retranslate existing titles.") paragraphs:paragraphs formattingWarningDismissed:dismissed];
}
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title paragraphs:(NSArray<FKParagraph *> *)paragraphs formattingWarningDismissed:(BOOL)dismissed {
    NSParameterAssert(title);
    NSParameterAssert(paragraphs.count > 0);
    if ((self = [super initWithIdentifier:identifier])) {
        _title = [title copy];
        _paragraphs = [paragraphs copy];
        _formattingWarningDismissed = dismissed;
    }
    return self;
}
- (NSString *)string {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (FKParagraph *paragraph in self.paragraphs) [strings addObject:paragraph.string];
    return [strings componentsJoinedByString:@"\n"];
}
@end

@implementation FKManuscript
- (instancetype)initWithIdentifier:(NSString *)identifier {
    return [self initWithIdentifier:identifier units:@[[FKText new]]];
}
- (instancetype)initWithIdentifier:(NSString *)identifier units:(NSArray<FKText *> *)units {
    NSParameterAssert(units.count > 0);
    NSParameterAssert([NSSet setWithArray:[units valueForKey:@"identifier"]].count == units.count);
    if ((self = [super initWithIdentifier:identifier])) _units = [units copy];
    return self;
}
@end
