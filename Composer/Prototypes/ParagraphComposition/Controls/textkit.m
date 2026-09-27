// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

// Standalone, throwaway TextKit 2 control probe. Compile with:
// xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework AppKit -framework CoreText textkit.m -o textkit

#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <sys/utsname.h>

static NSString *FCRasterOutputDirectory;

static NSDictionary *FCRaster(NSString *name, NSArray<NSTextLayoutFragment *> *fragments) {
    const size_t scale = 8, width = 120 * scale, height = 28 * scale;
    CGColorSpaceRef colors = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colors,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colors);
    if (!context) return @{ @"error": @"bitmap context unavailable" };
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, 0, 22);
    CGContextScaleCTM(context, 1, -1);
    for (NSTextLayoutFragment *fragment in fragments)
        [fragment drawAtPoint:fragment.layoutFragmentFrame.origin inContext:context];
    uint8_t *pixels = CGBitmapContextGetData(context);
    NSMutableArray *runs = [NSMutableArray array];
    NSInteger beginning = -1;
    for (size_t x = 0; x <= width; x++) {
        BOOL ink = NO;
        if (x < width) for (size_t y = 0; y < height; y++) {
            uint8_t *pixel = pixels + (y * width + x) * 4;
            if (pixel[0] < 128 || pixel[1] < 128 || pixel[2] < 128) { ink = YES; break; }
        }
        if (ink && beginning < 0) beginning = (NSInteger)x;
        if (!ink && beginning >= 0) {
            [runs addObject:@{ @"firstXPoints": @((double)beginning / scale),
                                @"lastXPoints": @((double)(x - 1) / scale) }];
            beginning = -1;
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    NSString *filename = [name stringByAppendingPathExtension:@"png"];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    BOOL wrote = [png writeToFile:[FCRasterOutputDirectory stringByAppendingPathComponent:filename] atomically:YES];
    return @{ @"scalePixelsPerPoint": @(scale), @"inkColumnRuns": runs,
              @"image": filename, @"imageWritten": @(wrote) };
}

@interface FCBreakDelegate : NSObject <NSTextLayoutManagerDelegate>
@property (nonatomic, weak) NSTextContentManager *storage;
@property (nonatomic, copy) NSSet<NSNumber *> *allowed;
@property (nonatomic) BOOL vetoAll;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@end

@implementation FCBreakDelegate
- (instancetype)init {
    if ((self = [super init])) _calls = [NSMutableArray array];
    return self;
}
- (BOOL)textLayoutManager:(NSTextLayoutManager *)manager
    shouldBreakLineBeforeLocation:(id<NSTextLocation>)location hyphenating:(BOOL)hyphenating {
    (void)manager;
    NSInteger offset = [self.storage offsetFromLocation:self.storage.documentRange.location toLocation:location];
    BOOL allow = !self.vetoAll && (!self.allowed || [self.allowed containsObject:@(offset)]);
    [self.calls addObject:@{ @"offsetUTF16": @(offset), @"hyphenating": @(hyphenating),
                             @"allow": @(allow) }];
    return allow;
}
@end

static NSDictionary *FCRect(NSRect r) {
    return @{ @"x": @(r.origin.x), @"y": @(r.origin.y),
              @"width": @(r.size.width), @"height": @(r.size.height) };
}

static NSDictionary *FCLayout(NSString *name, NSString *text, NSFont *font, CGFloat width,
                              CGFloat tracking, BOOL hyphenate, NSSet<NSNumber *> *allowed,
                              BOOL vetoAll, BOOL delegateEnabled, NSTextAlignment alignment,
                              CGFloat firstLineHeadIndent, CGFloat quoteKern, CGFloat horizontalScale) {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = alignment;
    style.hyphenationFactor = hyphenate ? 1.0 : 0.0;
    style.usesDefaultHyphenation = NO;
    style.firstLineHeadIndent = firstLineHeadIndent;
    if (horizontalScale != 1.0) {
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform scaleXBy:font.pointSize * horizontalScale yBy:font.pointSize];
        NSFont *scaled = [NSFont fontWithDescriptor:font.fontDescriptor textTransform:transform];
        if (scaled) font = scaled;
    }
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:text
        attributes:@{ NSFontAttributeName: font, NSParagraphStyleAttributeName: style,
                      (__bridge NSString *)kCTLanguageAttributeName: @"en" }];
    // Core Text ignores nonzero kern when the tracking key is also present, even at zero.
    if (tracking != 0) [attributed addAttribute:NSTrackingAttributeName value:@(tracking)
                                         range:NSMakeRange(0, text.length)];
    if (quoteKern && text.length) [attributed addAttribute:NSKernAttributeName value:@(quoteKern)
                                                     range:NSMakeRange(0, 1)];
    NSTextContentStorage *storage = [[NSTextContentStorage alloc] init];
    storage.textStorage = [[NSTextStorage alloc] initWithAttributedString:attributed];
    NSTextLayoutManager *manager = [[NSTextLayoutManager alloc] init];
    manager.usesHyphenation = hyphenate;
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:NSMakeSize(width, 10000)];
    container.lineFragmentPadding = 0;
    manager.textContainer = container;
    [storage addTextLayoutManager:manager];
    FCBreakDelegate *delegate = [[FCBreakDelegate alloc] init];
    delegate.storage = storage;
    delegate.allowed = allowed;
    delegate.vetoAll = vetoAll;
    if (delegateEnabled) manager.delegate = delegate;
    [manager ensureLayoutForRange:storage.documentRange];
    NSMutableArray *lines = [NSMutableArray array];
    NSMutableArray *breaks = [NSMutableArray array];
    NSMutableArray *intraword = [NSMutableArray array];
    NSMutableArray<NSTextLayoutFragment *> *fragments = [NSMutableArray array];
    __block NSUInteger next = 0;
    __block BOOL coverage = YES;
    [manager enumerateTextLayoutFragmentsFromLocation:nil options:0 usingBlock:^BOOL(NSTextLayoutFragment *fragment) {
        [fragments addObject:fragment];
        NSInteger fragmentStart = [storage offsetFromLocation:storage.documentRange.location
                                                   toLocation:fragment.rangeInElement.location];
        for (NSTextLineFragment *line in fragment.textLineFragments) {
            NSRange local = line.characterRange;
            if (fragmentStart < 0 || local.location > text.length || local.length > text.length - local.location) {
                coverage = NO;
                continue;
            }
            NSUInteger start = (NSUInteger)fragmentStart + local.location;
            NSUInteger end = start + local.length;
            if (start != next || end > text.length) coverage = NO;
            next = end;
            NSMutableArray *positions = [NSMutableArray array];
            for (NSUInteger i = start; i <= end; i++) {
                NSPoint p = [line locationForCharacterAtIndex:(NSInteger)i];
                [positions addObject:@{ @"indexUTF16": @(i), @"xLocal": @(p.x),
                                        @"xInContainer": @(p.x + fragment.layoutFragmentFrame.origin.x),
                                        @"y": @(p.y) }];
            }
            [lines addObject:@{ @"rangeUTF16": @[@(start), @(local.length)],
                                @"text": [text substringWithRange:NSMakeRange(start, local.length)],
                                @"typographicBounds": FCRect(line.typographicBounds),
                                @"fragmentFrame": FCRect(fragment.layoutFragmentFrame),
                                @"positions": positions }];
            if (end < text.length) {
                [breaks addObject:@(end)];
                unichar before = end ? [text characterAtIndex:end - 1] : 0;
                unichar after = [text characterAtIndex:end];
                BOOL inside = [[NSCharacterSet letterCharacterSet] characterIsMember:before] &&
                              [[NSCharacterSet letterCharacterSet] characterIsMember:after];
                if (inside) [intraword addObject:@(end)];
            }
        }
        return YES;
    }];
    coverage = coverage && next == text.length;
    NSDictionary *raster = [name hasPrefix:@"punctuation-"] && ![name isEqualToString:@"punctuation-justified"]
        ? FCRaster(name, fragments) : @{};
    return @{ @"name": name, @"request": @{ @"text": text, @"widthPoints": @(width),
                   @"trackingPoints": @(tracking), @"usesHyphenation": @(hyphenate),
                   @"trackingAttributePresent": @(tracking != 0),
                   @"initialQuoteKernAttributePresent": @(quoteKern != 0),
                   @"firstLineHeadIndentPoints": @(firstLineHeadIndent),
                   @"initialQuoteKernPoints": @(quoteKern),
                   @"fontHorizontalScale": @(horizontalScale),
                   @"languageAttribute": @"en",
                   @"paragraphHyphenationFactor": @(style.hyphenationFactor),
                   @"delegate": @(delegateEnabled), @"vetoAll": @(vetoAll),
                   @"allowedBreakOffsetsUTF16": allowed ? [[allowed allObjects] sortedArrayUsingSelector:@selector(compare:)] : [NSNull null],
                   @"alignment": @(alignment) },
              @"actual": @{ @"lines": lines, @"breakOffsetsUTF16": breaks,
                             @"intrawordBreakOffsetsUTF16": intraword,
                             @"delegateCalls": delegate.calls,
                             @"completeRangeCoverage": @(coverage),
                             @"coveredUTF16Length": @(next),
                             @"usageBounds": FCRect(manager.usageBoundsForTextContainer),
                             @"raster": raster } };
}

static BOOL FCWriteJSON(NSDictionary *object, NSString *path) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        fprintf(stderr, "write failed: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    return YES;
}

static NSDictionary *FCFind(NSArray<NSDictionary *> *cases, NSString *name) {
    for (NSDictionary *item in cases) if ([item[@"name"] isEqualToString:name]) return item;
    return nil;
}

static CGFloat FCWidth(NSDictionary *item, NSUInteger line) {
    NSArray *lines = item[@"actual"][@"lines"];
    return line < lines.count ? [lines[line][@"typographicBounds"][@"width"] doubleValue] : NAN;
}

static CGFloat FCX(NSDictionary *item, NSUInteger line, NSUInteger index) {
    NSArray *lines = item[@"actual"][@"lines"];
    NSArray *positions = line < lines.count ? lines[line][@"positions"] : nil;
    return index < positions.count ? [positions[index][@"xInContainer"] doubleValue] : NAN;
}

static NSArray<NSDictionary *> *FCInkRuns(NSDictionary *item) {
    return item[@"actual"][@"raster"][@"inkColumnRuns"];
}

static NSDictionary *FCContract(NSString *expectation, BOOL pass, NSDictionary *observations) {
    return @{ @"expectation": expectation, @"pass": @(pass), @"observations": observations ?: @{} };
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *output = @"/tmp/folio-textkit-controls";
        if (argc == 3 && strcmp(argv[1], "--output") == 0) output = @(argv[2]);
        else if (argc != 1) { fprintf(stderr, "usage: textkit [--output directory]\n"); return 2; }
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:&error]) {
            fprintf(stderr, "directory failed: %s\n", error.localizedDescription.UTF8String); return 2;
        }
        FCRasterOutputDirectory = output;
        NSFont *font = [NSFont fontWithName:@"Times-Roman" size:12];
        if (!font || ![font.fontName isEqualToString:@"Times-Roman"]) {
            fprintf(stderr, "Times-Roman unavailable\n"); return 2;
        }
        NSString *plain = @"extraordinary extraordinary extraordinary";
        NSString *soft = @"ex\u00adtra\u00ador\u00addinary ex\u00adtra\u00ador\u00addinary";
        NSMutableArray *cases = [NSMutableArray array];
        [cases addObject:FCLayout(@"automatic-disabled-wide", plain, font, 100, 0, NO, nil, NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"automatic-disabled-narrow", plain, font, 58, 0, NO, nil, NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"automatic-enabled-narrow", plain, font, 58, 0, YES, nil, NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"soft-hyphen-baseline", soft, font, 58, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 1)];
        NSMutableSet *softOffsets = [NSMutableSet set];
        for (NSUInteger i = 0; i < soft.length; i++) if ([soft characterAtIndex:i] == 0x00ad) [softOffsets addObject:@(i + 1)];
        [cases addObject:FCLayout(@"soft-hyphen-all-allowed", soft, font, 58, 0, NO, softOffsets, NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"soft-hyphen-selected-only-adversarial", soft, font, 58, 0, NO, [NSSet setWithObject:@3], NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"soft-hyphen-all-vetoed-adversarial", soft, font, 58, 0, NO, nil, YES, YES, NSTextAlignmentLeft, 0, 0, 1)];
        NSString *feasibleText = @"Today ex\u00adtra\u00ador\u00addinary";
        [cases addObject:FCLayout(@"soft-hyphen-feasible-baseline", feasibleText, font, 80, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"soft-hyphen-feasible-selected", feasibleText, font, 80, 0, NO, [NSSet setWithObject:@9], NO, YES, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"tracking-zero", @"HHHH", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"tracking-half", @"HHHH", font, 300, 0.5, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 1)];
        [cases addObject:FCLayout(@"font-scale-098", @"HHHH", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 0.98)];
        [cases addObject:FCLayout(@"font-scale-102", @"HHHH", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 0, 0, 1.02)];
        [cases addObject:FCLayout(@"punctuation-left", @"\u201cHello, world.\u201d", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 10, 0, 1)];
        [cases addObject:FCLayout(@"punctuation-indent-half", @"\u201cHello, world.\u201d", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 9.5, 0.5, 1)];
        [cases addObject:FCLayout(@"punctuation-indent-one", @"\u201cHello, world.\u201d", font, 300, 0, NO, nil, NO, NO, NSTextAlignmentLeft, 9, 1, 1)];
        [cases addObject:FCLayout(@"punctuation-justified", @"\u201cHello, world.\u201d \u201cHello, world.\u201d", font, 75, 0, NO, nil, NO, NO, NSTextAlignmentJustified, 0, 0, 1)];
        NSDictionary *allowed = FCFind(cases, @"soft-hyphen-all-allowed");
        NSDictionary *feasibleBase = FCFind(cases, @"soft-hyphen-feasible-baseline");
        NSDictionary *feasible = FCFind(cases, @"soft-hyphen-feasible-selected");
        NSDictionary *trackingZero = FCFind(cases, @"tracking-zero");
        NSDictionary *trackingHalf = FCFind(cases, @"tracking-half");
        NSDictionary *punctuationBase = FCFind(cases, @"punctuation-left");
        CGFloat trackingOffset3Delta = FCX(trackingHalf, 0, 3) - FCX(trackingZero, 0, 3);
        CGFloat trackingOffset4Delta = FCX(trackingHalf, 0, 4) - FCX(trackingZero, 0, 4);
        NSMutableArray *annotated = [NSMutableArray array];
        for (NSDictionary *item in cases) {
            NSString *name = item[@"name"];
            NSArray *breaks = item[@"actual"][@"breakOffsetsUTF16"];
            NSArray *intraword = item[@"actual"][@"intrawordBreakOffsetsUTF16"];
            NSArray *calls = item[@"actual"][@"delegateCalls"];
            BOOL coverage = [item[@"actual"][@"completeRangeCoverage"] boolValue];
            NSDictionary *contract = nil;
            if ([name isEqualToString:@"automatic-disabled-wide"]) {
                BOOL noAutoCalls = YES;
                for (NSDictionary *call in calls) if ([call[@"hyphenating"] boolValue]) noAutoCalls = NO;
                contract = FCContract(@"Disabled automatic hyphenation has no auto-hyphenation candidates or intraword breaks when each word fits the measure.",
                    coverage && noAutoCalls && intraword.count == 0, @{ @"candidateCount": @(calls.count) });
            } else if ([name isEqualToString:@"automatic-disabled-narrow"]) {
                contract = FCContract(@"A too-narrow measure still yields complete layout, exposing emergency intraword breaks without auto-hyphenation candidates.",
                    coverage && intraword.count > 0, @{ @"emergencyBreakOffsetsUTF16": intraword });
            } else if ([name isEqualToString:@"automatic-enabled-narrow"]) {
                BOOL autoCall = NO;
                for (NSDictionary *call in calls) if ([call[@"hyphenating"] boolValue]) autoCall = YES;
                contract = FCContract(@"Automatic hyphenation proposes at least one intraword break through the delegate.",
                    coverage && autoCall && intraword.count > 0, @{ @"intrawordBreakOffsetsUTF16": intraword });
            } else if ([name isEqualToString:@"soft-hyphen-baseline"]) {
                contract = FCContract(@"Native layout consumes the source, including explicit soft hyphens, with complete range coverage.", coverage,
                    @{ @"breakOffsetsUTF16": breaks });
            } else if ([name isEqualToString:@"soft-hyphen-all-allowed"]) {
                NSSet *allowedSet = [NSSet setWithArray:allowed[@"request"][@"allowedBreakOffsetsUTF16"]];
                BOOL subset = YES;
                for (NSNumber *offset in breaks) if (![allowedSet containsObject:offset]) subset = NO;
                contract = FCContract(@"With the offered soft-hyphen candidates allowed, every resulting break is at an allowed offset.",
                    coverage && subset && breaks.count > 0, @{ @"breakOffsetsUTF16": breaks });
            } else if ([name isEqualToString:@"soft-hyphen-selected-only-adversarial"]) {
                BOOL onlyAllowed = YES;
                NSMutableArray *unapproved = [NSMutableArray array];
                for (NSNumber *offset in breaks) if (offset.unsignedIntegerValue != 3) {
                    onlyAllowed = NO;
                    [unapproved addObject:offset];
                }
                contract = FCContract(@"At a narrow measure, every break remains at the only allowed candidate (UTF-16 offset 3).",
                    coverage && onlyAllowed, @{ @"unapprovedBreakOffsetsUTF16": unapproved,
                                               @"unapprovedIntrawordBreakOffsetsUTF16": intraword });
            } else if ([name isEqualToString:@"soft-hyphen-all-vetoed-adversarial"]) {
                contract = FCContract(@"All vetoes suppress every line break, including emergency breaks.",
                    coverage && breaks.count == 0, @{ @"breakOffsetsUTF16": breaks });
            } else if ([name isEqualToString:@"soft-hyphen-feasible-baseline"]) {
                contract = FCContract(@"Unconstrained native choice is recorded for comparison with a feasible selected soft-hyphen break.",
                    coverage && breaks.count > 0, @{ @"breakOffsetsUTF16": breaks,
                                                     @"lineWidthsPoints": @[@(FCWidth(feasibleBase, 0)), @(FCWidth(feasibleBase, 1))] });
            } else if ([name isEqualToString:@"soft-hyphen-feasible-selected"]) {
                BOOL calledAllowed = NO, rejectedOther = NO;
                for (NSDictionary *call in calls) {
                    if ([call[@"offsetUTF16"] unsignedIntegerValue] == 9 && [call[@"allow"] boolValue]) calledAllowed = YES;
                    if (![call[@"allow"] boolValue]) rejectedOther = YES;
                }
                BOOL fits = FCWidth(feasible, 0) <= 80 && FCWidth(feasible, 1) <= 80;
                contract = FCContract(@"A feasible requested break at explicit soft-hyphen offset 9 is selected; all lines fit 80 points and other offered candidates are vetoed.",
                    coverage && [breaks isEqualToArray:@[@9]] && calledAllowed && rejectedOther && fits,
                    @{ @"lineWidthsPoints": @[@(FCWidth(feasible, 0)), @(FCWidth(feasible, 1))],
                       @"baselineBreakOffsetsUTF16": feasibleBase[@"actual"][@"breakOffsetsUTF16"] });
            } else if ([name isEqualToString:@"tracking-zero"]) {
                contract = FCContract(@"Untracked HHHH supplies a reference width and caret offsets.", coverage,
                    @{ @"widthPoints": @(FCWidth(trackingZero, 0)) });
            } else if ([name isEqualToString:@"tracking-half"]) {
                contract = FCContract(@"0.5-point tracking changes HHHH width by 2 points and final caret offset by 1.5 points.",
                    coverage && fabs(FCWidth(trackingHalf, 0) - FCWidth(trackingZero, 0) - 2.0) < 0.01 &&
                    fabs(trackingOffset4Delta - 1.5) < 0.01,
                    @{ @"caretOffset3DeltaPoints": @(trackingOffset3Delta),
                       @"caretOffset4DeltaPoints": @(trackingOffset4Delta),
                       @"widthDeltaPoints": @(FCWidth(trackingHalf, 0) - FCWidth(trackingZero, 0)) });
            } else if ([name isEqualToString:@"font-scale-098"] || [name isEqualToString:@"font-scale-102"]) {
                CGFloat scale = [name isEqualToString:@"font-scale-098"] ? 0.98 : 1.02;
                CGFloat ratio = FCWidth(item, 0) / FCWidth(trackingZero, 0);
                contract = FCContract(@"A fixed NSFont horizontal text transform changes HHHH width by the requested ratio.",
                    coverage && fabs(ratio - scale) < 0.001,
                    @{ @"measuredWidthRatio": @(ratio), @"baselineWidthPoints": @(FCWidth(trackingZero, 0)) });
            } else if ([name isEqualToString:@"punctuation-left"]) {
                contract = FCContract(@"A 10-point first-line indent sets a measurable reference edge for the initial quotation mark.",
                    coverage && fabs(FCX(item, 0, 0) - 10) < 0.01,
                    @{ @"quoteCaretXPoints": @(FCX(item, 0, 0)), @"followingCaretXPoints": @(FCX(item, 0, 1)) });
            } else if ([name hasPrefix:@"punctuation-indent-"]) {
                CGFloat amount = [name hasSuffix:@"half"] ? 0.5 : 1.0;
                CGFloat quoteDelta = FCX(item, 0, 0) - FCX(punctuationBase, 0, 0);
                CGFloat nextDelta = FCX(item, 0, 1) - FCX(punctuationBase, 0, 1);
                NSArray *baseInk = FCInkRuns(punctuationBase), *caseInk = FCInkRuns(item);
                BOOL inkAligned = baseInk.count == caseInk.count && baseInk.count >= 3;
                for (NSUInteger i = 0; inkAligned && i < baseInk.count; i++) {
                    CGFloat expected = i < 2 ? -amount : 0;
                    for (NSString *edge in @[@"firstXPoints", @"lastXPoints"])
                        if (fabs([caseInk[i][edge] doubleValue] - [baseInk[i][edge] doubleValue] - expected) > 0.001)
                            inkAligned = NO;
                }
                id quoteInkDelta = baseInk.count > 0 && caseInk.count > 0
                    ? @([caseInk[0][@"firstXPoints"] doubleValue] - [baseInk[0][@"firstXPoints"] doubleValue])
                    : [NSNull null];
                id followingInkDelta = baseInk.count > 2 && caseInk.count > 2
                    ? @([caseInk[2][@"firstXPoints"] doubleValue] - [baseInk[2][@"firstXPoints"] doubleValue])
                    : [NSNull null];
                contract = FCContract(@"Moving the first-line indent left and applying equal positive kern to the quote moves only the quote ink by the requested amount while keeping following text ink fixed.",
                    coverage && [item[@"actual"][@"raster"][@"imageWritten"] boolValue] &&
                    fabs(quoteDelta + amount) < 0.01 && inkAligned,
                    @{ @"quoteCaretDeltaPoints": @(quoteDelta), @"followingCaretDeltaPoints": @(nextDelta),
                       @"quoteInkFirstXDeltaPoints": quoteInkDelta,
                       @"followingInkFirstXDeltaPoints": followingInkDelta,
                       @"allFollowingInkColumnRunsIdentical": @(inkAligned) });
            } else {
                contract = FCContract(@"Justified native text has complete UTF-16 range coverage and a first line at the specified 75-point measure.",
                    coverage && fabs(FCWidth(item, 0) - 75) < 0.01,
                    @{ @"firstLineWidthPoints": @(FCWidth(item, 0)) });
            }
            NSMutableDictionary *annotatedCase = [item mutableCopy];
            annotatedCase[@"contract"] = contract;
            [annotated addObject:annotatedCase];
        }
        struct utsname sys; uname(&sys);
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
        CFStringRef fontVersion = CTFontCopyName(ctFont, kCTFontVersionNameKey);
        NSDictionary *result = @{ @"schemaVersion": @1,
            @"environment": @{ @"os": NSProcessInfo.processInfo.operatingSystemVersionString,
                                @"kernel": @(sys.release), @"machine": @(sys.machine),
                                @"sdkVersion": @(__MAC_OS_X_VERSION_MAX_ALLOWED),
                                @"preferredLanguages": NSLocale.preferredLanguages },
            @"font": @{ @"postScriptName": font.fontName, @"pointSize": @(font.pointSize),
                        @"version": fontVersion ? (__bridge NSString *)fontVersion : @"unknown" },
            @"notes": @[
                @"Soft hyphens in the synthetic specimen expose explicit discretionary candidates; they do not validate linguistic hyphenation.",
                @"A delegate veto is not a hard prohibition when the requested constraints make wrapping infeasible; emergency breaks remain possible.",
                @"NSExpansionAttributeName is documented as unsupported with TextKit 2 in the selected SDK. A fixed NSFont horizontal transform works; automatic per-line glyph expansion was not exercised.",
                @"The first-line indent plus initial quote kern controls this opening-quote protrusion, but no documented TextKit 2 paragraph API exposes an arbitrary line-edge punctuation protrusion table.",
                @"Line-fragment character positions are caret offsets, not measured glyph ink origins."
            ],
            @"cases": annotated };
        BOOL wrote = FCWriteJSON(result, [output stringByAppendingPathComponent:@"results.json"]);
        if (fontVersion) CFRelease(fontVersion);
        CFRelease(ctFont);
        if (!wrote) return 1;
        printf("wrote %lu cases to %s\n", (unsigned long)cases.count, output.UTF8String);
    }
    return 0;
}
