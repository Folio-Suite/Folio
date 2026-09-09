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

@implementation FKTextRun
- (instancetype)initWithString:(NSString *)string meaning:(FKTextMeaning)meaning appearance:(FKTextAppearance)appearance {
    NSParameterAssert(string);
    if ((self = [super init])) {
        _string = [string copy];
        _meaning = meaning;
        _appearance = appearance;
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
    NSParameterAssert(paragraphs.count > 0);
    if ((self = [super initWithIdentifier:identifier])) _paragraphs = [paragraphs copy];
    return self;
}
- (NSString *)string {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (FKParagraph *paragraph in self.paragraphs) [strings addObject:paragraph.string];
    return [strings componentsJoinedByString:@"\n"];
}
@end
