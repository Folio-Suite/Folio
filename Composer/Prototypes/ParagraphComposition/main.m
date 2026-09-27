// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <sys/utsname.h>

static const CGFloat FCPointSize = 12.0;
static const CGFloat FCMargin = 24.0;
static const CGFloat FCLayoutHeight = 100000.0;
static const CGFloat FCScale = 2.0;

static NSDictionary *FCRect(CGRect rect) {
    return @{ @"x": @(rect.origin.x), @"y": @(rect.origin.y),
              @"width": @(rect.size.width), @"height": @(rect.size.height) };
}

static NSString *FCFontName(CTFontRef font) {
    if (!font) return @"unknown";
    CFStringRef name = CTFontCopyPostScriptName(font);
    return CFBridgingRelease(name) ?: @"unknown";
}

static NSDictionary *FCFontRecord(CTFontRef font) {
    if (!font) return @{};
    CFStringRef version = CTFontCopyName(font, kCTFontVersionNameKey);
    NSDictionary *record = @{ @"postScriptName": FCFontName(font),
                              @"family": CFBridgingRelease(CTFontCopyFamilyName(font)) ?: @"unknown",
                              @"version": version ? (__bridge NSString *)version : @"unknown" };
    if (version) CFRelease(version);
    return record;
}

static NSArray *FCSpaceAdvances(NSString *text, NSRange range, CGFloat (^advance)(NSUInteger)) {
    NSMutableArray *values = [NSMutableArray array];
    for (NSUInteger i = range.location; i < NSMaxRange(range) && i < text.length; i++) {
        if ([text characterAtIndex:i] == ' ') {
            CGFloat value = advance(i);
            if (isfinite(value) && value >= 0) [values addObject:@(value)];
        }
    }
    return values;
}

static NSDictionary *FCCoverage(NSArray<NSDictionary *> *lines, NSUInteger length) {
    NSUInteger next = 0;
    NSMutableArray *gaps = [NSMutableArray array];
    NSMutableArray *overlaps = [NSMutableArray array];
    for (NSDictionary *line in lines) {
        NSUInteger start = [line[@"range"][0] unsignedIntegerValue];
        NSUInteger end = start + [line[@"range"][1] unsignedIntegerValue];
        if (start > next) [gaps addObject:@[@(next), @(start - next)]];
        if (start < next) [overlaps addObject:@[@(start), @(next - start)]];
        next = MAX(next, end);
    }
    if (next < length) [gaps addObject:@[@(next), @(length - next)]];
    BOOL complete = gaps.count == 0 && overlaps.count == 0 && next == length;
    return @{ @"complete": @(complete),
              @"coveredUTF16Length": @(MIN(next, length)), @"expectedUTF16Length": @(length),
              @"gaps": gaps, @"overlaps": overlaps, @"lastEnd": @(next) };
}

static BOOL FCWritePNG(NSString *path, CGFloat width, CGFloat height,
                       void (^draw)(CGContextRef, CGFloat)) {
    size_t pxWidth = (size_t)ceil(width * FCScale);
    size_t pxHeight = (size_t)ceil(height * FCScale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, pxWidth, pxHeight, 8, 0,
                                                 colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context) return NO;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, pxWidth, pxHeight));
    CGContextScaleCTM(context, FCScale, FCScale);
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    draw(context, height);
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (!image) return NO;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    NSData *data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [data writeToFile:path atomically:YES];
}

static NSMutableAttributedString *FCAppKitText(NSString *text, NSString *language,
                                                NSFont *font, BOOL hyphenate) {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentJustified;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.hyphenationFactor = hyphenate ? 1.0 : 0.0;
    style.usesDefaultHyphenation = NO;
    return [[NSMutableAttributedString alloc] initWithString:text
        attributes:@{ NSFontAttributeName: font, NSParagraphStyleAttributeName: style,
                      (__bridge NSString *)kCTLanguageAttributeName: language,
                      NSForegroundColorAttributeName: NSColor.blackColor }];
}

static NSMutableAttributedString *FCCoreTextText(NSString *text, NSString *language,
                                                  CTFontRef font) {
    CTTextAlignment alignment = kCTTextAlignmentJustified;
    CTLineBreakMode wrap = kCTLineBreakByWordWrapping;
    CTParagraphStyleSetting settings[] = {
        { kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment },
        { kCTParagraphStyleSpecifierLineBreakMode, sizeof(wrap), &wrap }
    };
    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, 2);
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:text
        attributes:@{ (__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
                      (__bridge NSString *)kCTParagraphStyleAttributeName: (__bridge id)style,
                      (__bridge NSString *)kCTLanguageAttributeName: language,
                      (__bridge NSString *)kCTForegroundColorAttributeName: (__bridge id)CGColorGetConstantColor(kCGColorBlack) }];
    CFRelease(style);
    return result;
}

static NSDictionary *FCTextKitCase(NSString *text, NSString *language, NSFont *font,
                                   CGFloat measure, BOOL hyphenate, NSString *imagePath) {
    NSMutableAttributedString *attributed = FCAppKitText(text, language, font, hyphenate);
    NSTextContentStorage *storage = [[NSTextContentStorage alloc] init];
    storage.textStorage = [[NSTextStorage alloc] initWithAttributedString:attributed];
    NSTextLayoutManager *manager = [[NSTextLayoutManager alloc] init];
    manager.usesHyphenation = hyphenate;
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(measure, FCLayoutHeight)];
    container.lineFragmentPadding = 0;
    container.maximumNumberOfLines = 0;
    manager.textContainer = container;
    [storage addTextLayoutManager:manager];
    [manager ensureLayoutForRange:storage.documentRange];

    NSMutableArray<NSTextLayoutFragment *> *fragments = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *lines = [NSMutableArray array];
    __block CGFloat lowest = 0;
    [manager enumerateTextLayoutFragmentsFromLocation:nil options:0 usingBlock:^BOOL(NSTextLayoutFragment *fragment) {
        [fragments addObject:fragment];
        lowest = MAX(lowest, CGRectGetMaxY(fragment.layoutFragmentFrame));
        NSUInteger fragmentStart = (NSUInteger)[storage offsetFromLocation:storage.documentRange.location
                                                               toLocation:fragment.rangeInElement.location];
        for (NSTextLineFragment *line in fragment.textLineFragments) {
            NSRange local = line.characterRange;
            NSUInteger start = fragmentStart + local.location;
            if (start > text.length || local.length > text.length - start) continue;
            NSRange range = NSMakeRange(start, local.length);
            CGRect box = line.typographicBounds;
            box.origin.x += fragment.layoutFragmentFrame.origin.x;
            box.origin.y += fragment.layoutFragmentFrame.origin.y;
            lowest = MAX(lowest, CGRectGetMaxY(box));
            NSArray *spaces = FCSpaceAdvances(text, range, ^CGFloat(NSUInteger index) {
                CGPoint first = [line locationForCharacterAtIndex:(NSInteger)index];
                CGPoint second = [line locationForCharacterAtIndex:(NSInteger)index + 1];
                return fabs(second.x - first.x);
            });
            [lines addObject:@{ @"range": @[@(start), @(range.length)],
                                @"text": [text substringWithRange:range],
                                @"breakUTF16": @(NSMaxRange(range)),
                                @"typographicBounds": FCRect(box),
                                @"spaceAdvances": spaces }];
        }
        return YES;
    }];
    CGFloat height = MAX(ceil(lowest + 2 * FCMargin), 2 * FCMargin + FCPointSize);
    BOOL wrote = FCWritePNG(imagePath, measure + 2 * FCMargin, height,
        ^(CGContextRef context, CGFloat imageHeight) {
            (void)imageHeight;
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, FCMargin, height - FCMargin);
            CGContextScaleCTM(context, 1, -1);
            for (NSTextLayoutFragment *fragment in fragments)
                [fragment drawAtPoint:fragment.layoutFragmentFrame.origin inContext:context];
            CGContextRestoreGState(context);
        });
    return @{ @"lines": lines, @"coverage": FCCoverage(lines, text.length),
              @"layoutFragmentCount": @(fragments.count), @"usageBounds": FCRect(manager.usageBoundsForTextContainer),
              @"imageWritten": @(wrote), @"imageSizePoints": @[@(measure + 2 * FCMargin), @(height)],
              @"effectiveControls": @{ @"justified": @YES, @"hyphenationRequested": @(hyphenate),
                                         @"hyphenationControl": @"NSTextLayoutManager.usesHyphenation and NSParagraphStyle.hyphenationFactor",
                                         @"languageAttribute": language, @"lineFragmentPadding": @0 },
              @"unsupportedMeasurements": @[@"Actual glyph-run fallback fonts are not exposed by NSTextLineFragment.",
                                            @"Word-space advances are text-location differences; exact glyph spacing and paragraph quality score are not exposed."] };
}

static NSDictionary *FCCoreTextCase(NSString *text, NSString *language, CTFontRef font,
                                    CGFloat measure, BOOL hyphenate, NSString *imagePath) {
    NSMutableAttributedString *attributed = FCCoreTextText(text, language, font);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, measure, FCLayoutHeight));
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    NSArray *ctLines = (__bridge NSArray *)CTFrameGetLines(frame);
    CGPoint *origins = calloc(MAX(ctLines.count, 1), sizeof(CGPoint));
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
    NSMutableArray *lines = [NSMutableArray array];
    NSMutableSet *runFonts = [NSMutableSet set];
    CGFloat lowest = 0;
    for (NSUInteger i = 0; i < ctLines.count; i++) {
        CTLineRef line = (__bridge CTLineRef)ctLines[i];
        CFRange raw = CTLineGetStringRange(line);
        if (raw.location < 0 || raw.length < 0 || (NSUInteger)(raw.location + raw.length) > text.length) continue;
        NSRange range = NSMakeRange((NSUInteger)raw.location, (NSUInteger)raw.length);
        CGFloat ascent = 0, descent = 0, leading = 0;
        double advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat top = FCLayoutHeight - origins[i].y - ascent;
        lowest = MAX(lowest, top + ascent + descent + leading);
        NSMutableArray *runs = [NSMutableArray array];
        for (id runObject in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
            CTRunRef run = (__bridge CTRunRef)runObject;
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            CTFontRef runFont = CFDictionaryGetValue(attributes, kCTFontAttributeName);
            CFRange runRange = CTRunGetStringRange(run);
            NSString *name = FCFontName(runFont);
            [runFonts addObject:name];
            [runs addObject:@{ @"range": @[@(runRange.location), @(runRange.length)],
                                @"font": FCFontRecord(runFont), @"glyphCount": @(CTRunGetGlyphCount(run)) }];
        }
        NSArray *spaces = FCSpaceAdvances(text, range, ^CGFloat(NSUInteger index) {
            CGFloat first = CTLineGetOffsetForStringIndex(line, (CFIndex)index, NULL);
            CGFloat second = CTLineGetOffsetForStringIndex(line, (CFIndex)index + 1, NULL);
            return fabs(second - first);
        });
        [lines addObject:@{ @"range": @[@(range.location), @(range.length)],
                            @"text": [text substringWithRange:range], @"breakUTF16": @(NSMaxRange(range)),
                            @"typographicBounds": FCRect(CGRectMake(origins[i].x, top, advance, ascent + descent)),
                            @"baselineFromTop": @(FCLayoutHeight - origins[i].y),
                            @"ascent": @(ascent), @"descent": @(descent), @"leading": @(leading),
                            @"spaceAdvances": spaces, @"runs": runs }];
    }
    CGFloat height = MAX(ceil(lowest + 2 * FCMargin), 2 * FCMargin + FCPointSize);
    BOOL wrote = FCWritePNG(imagePath, measure + 2 * FCMargin, height,
        ^(CGContextRef context, CGFloat imageHeight) {
            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
            for (NSUInteger i = 0; i < ctLines.count; i++) {
                CGContextSetTextPosition(context, FCMargin + origins[i].x,
                    imageHeight - FCMargin - (FCLayoutHeight - origins[i].y));
                CTLineDraw((__bridge CTLineRef)ctLines[i], context);
            }
        });
    free(origins);
    CFRange visible = CTFrameGetVisibleStringRange(frame);
    CFRelease(frame); CGPathRelease(path); CFRelease(setter);
    NSMutableSet *fallback = [runFonts mutableCopy];
    [fallback removeObject:FCFontName(font)];
    return @{ @"lines": lines, @"coverage": FCCoverage(lines, text.length),
              @"visibleUTF16Range": @[@(visible.location), @(visible.length)],
              @"runFonts": [[runFonts allObjects] sortedArrayUsingSelector:@selector(compare:)],
              @"fallbackRunFonts": [[fallback allObjects] sortedArrayUsingSelector:@selector(compare:)],
              @"imageWritten": @(wrote), @"imageSizePoints": @[@(measure + 2 * FCMargin), @(height)],
              @"effectiveControls": @{ @"justified": @YES, @"hyphenationRequested": @(hyphenate),
                                         @"hyphenationExercised": @NO, @"languageAttribute": language,
                                         @"lineBreakMode": @"wordWrapping" },
              @"unsupportedMeasurements": @[@"CTFramesetter has no public direct hyphenation toggle; this case uses its default behavior regardless of the requested setting.",
                                            @"Space advances are line-offset differences, not a paragraph quality score."] };
}

static void FCUsage(void) {
    fprintf(stderr, "usage: paragraph-composition --fixtures file.json --output directory [--font PostScriptName] [--font-file font.otf]\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSMutableDictionary<NSString *, NSString *> *options = [NSMutableDictionary dictionary];
        for (int i = 1; i < argc; i += 2) {
            if (i + 1 >= argc || strncmp(argv[i], "--", 2) != 0) { FCUsage(); return 2; }
            options[@(argv[i] + 2)] = @(argv[i + 1]);
        }
        NSString *fixturesPath = options[@"fixtures"];
        NSString *outputPath = options[@"output"];
        if (!fixturesPath || !outputPath) { FCUsage(); return 2; }
        NSError *error = nil;
        NSData *inputData = [NSData dataWithContentsOfFile:fixturesPath options:0 error:&error];
        NSDictionary *input = inputData ? [NSJSONSerialization JSONObjectWithData:inputData options:0 error:&error] : nil;
        NSArray *specimens = [input isKindOfClass:NSDictionary.class] ? input[@"specimens"] : nil;
        if (![specimens isKindOfClass:NSArray.class]) {
            fprintf(stderr, "invalid fixtures: %s\n", error.localizedDescription.UTF8String ?: "expected specimens array"); return 2;
        }
        if (specimens.count == 0) {
            fprintf(stderr, "invalid fixtures: specimens must not be empty\n"); return 2;
        }
        NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
        for (id raw in specimens) {
            NSString *identifier = [raw isKindOfClass:NSDictionary.class] ? raw[@"id"] : nil;
            if (![identifier isKindOfClass:NSString.class] || identifier.length == 0) continue;
            if ([identifiers containsObject:identifier]) {
                fprintf(stderr, "invalid fixtures: duplicate specimen id %s\n", identifier.UTF8String);
                return 2;
            }
            [identifiers addObject:identifier];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:outputPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) { fprintf(stderr, "output directory: %s\n", error.localizedDescription.UTF8String); return 2; }

        NSString *fontFile = options[@"font-file"];
        NSString *registeredName = nil;
        if (fontFile) {
            NSURL *url = [NSURL fileURLWithPath:fontFile];
            CFErrorRef registrationError = NULL;
            if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &registrationError)) {
                NSString *reason = registrationError ? [CFBridgingRelease(registrationError) description] : @"unknown";
                fprintf(stderr, "font registration failed: %s\n", reason.UTF8String); return 2;
            }
            CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
            if (descriptors && CFArrayGetCount(descriptors) > 0) {
                CTFontDescriptorRef descriptor = CFArrayGetValueAtIndex(descriptors, 0);
                registeredName = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute));
            }
            if (descriptors) CFRelease(descriptors);
        }
        NSString *requestedName = options[@"font"] ?: registeredName ?: @"Times-Roman";
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)requestedName, FCPointSize, NULL);
        NSString *actualName = FCFontName(ctFont);
        if (![actualName isEqualToString:requestedName]) {
            fprintf(stderr, "requested font %s resolved to %s\n", requestedName.UTF8String, actualName.UTF8String);
            CFRelease(ctFont); return 2;
        }
        NSFont *nsFont = [NSFont fontWithName:requestedName size:FCPointSize];
        if (!nsFont || ![nsFont.fontName isEqualToString:requestedName]) {
            fprintf(stderr, "AppKit could not resolve font %s\n", requestedName.UTF8String);
            CFRelease(ctFont); return 2;
        }
        struct utsname system;
        uname(&system);
        NSDictionary *environment = @{ @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString,
                                       @"kernel": @(system.release), @"machine": @(system.machine),
                                       @"sdkVersion": @(__MAC_OS_X_VERSION_MAX_ALLOWED),
                                       @"pointSize": @(FCPointSize), @"rasterScale": @(FCScale) };
        NSMutableArray *cases = [NSMutableArray array];
        BOOL allCasesComplete = YES;
        NSUInteger index = 0;
        for (id raw in specimens) {
            if (![raw isKindOfClass:NSDictionary.class]) { fprintf(stderr, "specimen must be object\n"); CFRelease(ctFont); return 2; }
            NSDictionary *specimen = raw;
            NSString *identifier = specimen[@"id"], *text = specimen[@"text"], *language = specimen[@"language"];
            if (![identifier isKindOfClass:NSString.class] || ![text isKindOfClass:NSString.class] ||
                ![language isKindOfClass:NSString.class] || !identifier.length || !text.length || !language.length) {
                fprintf(stderr, "specimen requires nonempty id, text, language strings\n"); CFRelease(ctFont); return 2;
            }
            for (NSNumber *width in @[@240, @300, @360]) {
                for (NSNumber *hyphenation in @[@NO, @YES]) {
                    for (NSString *engine in @[@"textkit2", @"coretext"]) {
                        NSString *filename = [NSString stringWithFormat:@"%03lu-%@-%@-%@.png", (unsigned long)index,
                            engine, width, hyphenation.boolValue ? @"hyphen-on" : @"hyphen-off"];
                        NSString *path = [outputPath stringByAppendingPathComponent:filename];
                        NSDictionary *result = [engine isEqualToString:@"textkit2"]
                            ? FCTextKitCase(text, language, nsFont, width.doubleValue, hyphenation.boolValue, path)
                            : FCCoreTextCase(text, language, ctFont, width.doubleValue, hyphenation.boolValue, path);
                        NSMutableDictionary *entry = [result mutableCopy];
                        CFLocaleRef locale = CFLocaleCreate(NULL, (__bridge CFStringRef)language);
                        BOOL hyphenationAvailable = CFStringIsHyphenationAvailableForLocale(locale);
                        CFRelease(locale);
                        [entry addEntriesFromDictionary:@{ @"specimenId": identifier, @"language": language,
                            @"coreFoundationHyphenationAvailableForLocale": @(hyphenationAvailable),
                            @"source": [specimen[@"source"] isKindOfClass:NSString.class] ? specimen[@"source"] : @"",
                            @"locator": [specimen[@"locator"] isKindOfClass:NSString.class] ? specimen[@"locator"] : @"",
                            @"engine": engine, @"measurePoints": width, @"requestedHyphenation": hyphenation,
                            @"image": filename, @"inputUTF16Length": @(text.length) }];
                        if (![entry[@"coverage"][@"complete"] boolValue] || ![entry[@"imageWritten"] boolValue])
                            allCasesComplete = NO;
                        [cases addObject:entry];
                    }
                }
            }
            index++;
        }
        NSDictionary *output = @{ @"schemaVersion": @1, @"complete": @(allCasesComplete), @"environment": environment,
            @"font": @{ @"requestedPostScriptName": requestedName, @"actualPostScriptName": actualName,
                        @"registeredFontFile": fontFile ?: [NSNull null], @"metadata": FCFontRecord(ctFont),
                        @"appKitPostScriptName": nsFont.fontName },
            @"limitations": @[@"This compares native line breaking and drawing; it does not identify either engine's private optimization algorithm.",
                               @"Core Text and TextKit 2 may use different hyphenation behavior; Core Text hyphenation is not explicitly controlled here.",
                               @"No custom paragraph or page break optimizer is exercised."],
            @"cases": cases };
        NSData *json = [NSJSONSerialization dataWithJSONObject:output options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        BOOL wrote = json && [json writeToFile:[outputPath stringByAppendingPathComponent:@"results.json"] atomically:YES];
        CFRelease(ctFont);
        if (!wrote) { fprintf(stderr, "results write failed: %s\n", error.localizedDescription.UTF8String ?: "unknown"); return 1; }
        if (!allCasesComplete) {
            fprintf(stderr, "one or more cases have incomplete line coverage or a missing PNG; inspect results.json\n");
            return 1;
        }
        fprintf(stdout, "wrote %lu cases to %s\n", (unsigned long)cases.count, outputPath.UTF8String);
        return 0;
    }
}
