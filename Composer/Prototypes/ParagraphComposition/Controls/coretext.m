// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

// Standalone caller-control experiment. This is deliberately outside ComposerKit.
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <sys/utsname.h>

static const CGFloat FCSize = 12, FCScale = 2, FCMargin = 30;

static NSDictionary *FCBox(CGRect r) {
    return @{ @"x": @(r.origin.x), @"y": @(r.origin.y),
              @"width": @(r.size.width), @"height": @(r.size.height) };
}

static CTFontRef FCFont(void) { return CTFontCreateWithName(CFSTR("Times-Roman"), FCSize, NULL); }

static NSAttributedString *FCText(NSString *s, CTFontRef font, NSNumber *tracking, CTParagraphStyleRef style) {
    NSMutableDictionary *attributes = [@{ (__bridge NSString *)kCTFontAttributeName: (__bridge id)font,
        (__bridge NSString *)kCTForegroundColorAttributeName: (__bridge id)CGColorGetConstantColor(kCGColorBlack) } mutableCopy];
    if (tracking) attributes[(__bridge NSString *)kCTTrackingAttributeName] = tracking;
    if (style) attributes[(__bridge NSString *)kCTParagraphStyleAttributeName] = (__bridge id)style;
    return [[NSAttributedString alloc] initWithString:s attributes:attributes];
}

static NSDictionary *FCMetrics(CTLineRef line, CGFloat originX, CGFloat horizontalScale) {
    CGFloat ascent = 0, descent = 0, leading = 0;
    double advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGRect ink = CTLineGetImageBounds(line, NULL);
    return @{ @"advancePoints": @(advance * horizontalScale),
        @"rawAdvancePoints": @(advance), @"originXPoints": @(originX),
        @"inkBoundsAtOriginPoints": FCBox(CGRectMake(originX + ink.origin.x * horizontalScale,
            ink.origin.y, ink.size.width * horizontalScale, ink.size.height)),
        @"ascentPoints": @(ascent), @"descentPoints": @(descent), @"leadingPoints": @(leading),
        @"glyphRuns": @(CFArrayGetCount(CTLineGetGlyphRuns(line))) };
}

static BOOL FCPNG(NSString *path, NSArray *lines, NSArray<NSNumber *> *origins,
                  NSArray<NSNumber *> *scales, CGFloat measure, CGFloat guideX) {
    CGFloat width = MAX(220, measure + 2 * FCMargin + 20), height = FCMargin * 2 + MAX(1, lines.count) * 25;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)ceil(width * FCScale),
        (size_t)ceil(height * FCScale), 8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return NO;
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, width * FCScale, height * FCScale));
    CGContextScaleCTM(ctx, FCScale, FCScale);
    CGContextSetLineWidth(ctx, .5);
    CGContextSetRGBStrokeColor(ctx, .7, .7, .7, 1);
    CGContextMoveToPoint(ctx, FCMargin, 0); CGContextAddLineToPoint(ctx, FCMargin, height);
    CGContextMoveToPoint(ctx, FCMargin + guideX, 0); CGContextAddLineToPoint(ctx, FCMargin + guideX, height);
    CGContextStrokePath(ctx);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    for (NSUInteger i = 0; i < lines.count; i++) {
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, FCMargin + origins[i].doubleValue, height - FCMargin - i * 25);
        CGContextScaleCTM(ctx, scales[i].doubleValue, 1);
        CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
        CTLineDraw((__bridge CTLineRef)lines[i], ctx);
        CGContextRestoreGState(ctx);
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx); CGContextRelease(ctx);
    if (!image) return NO;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image]; CGImageRelease(image);
    return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

// Extract already-shaped glyphs from the full line. Drawing below changes positions only.
static NSArray<NSDictionary *> *FCExtractRuns(CTLineRef line) {
    NSMutableArray *records = [NSMutableArray array];
    for (id runObject in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
        CTRunRef run = (__bridge CTRunRef)runObject;
        CFIndex count = CTRunGetGlyphCount(run);
        if (count <= 0) continue;
        CTFontRef font = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        NSMutableData *glyphs = [NSMutableData dataWithLength:(NSUInteger)count * sizeof(CGGlyph)];
        NSMutableData *positions = [NSMutableData dataWithLength:(NSUInteger)count * sizeof(CGPoint)];
        NSMutableData *indices = [NSMutableData dataWithLength:(NSUInteger)count * sizeof(CFIndex)];
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs.mutableBytes);
        CTRunGetPositions(run, CFRangeMake(0, 0), positions.mutableBytes);
        CTRunGetStringIndices(run, CFRangeMake(0, 0), indices.mutableBytes);
        [records addObject:@{ @"font": (__bridge id)font, @"glyphs": glyphs,
            @"positions": positions, @"stringIndices": indices, @"count": @(count) }];
    }
    return records;
}

// component: 0 draws every glyph, 1 only the opening quote, 2 only the interior.
static void FCDrawExtractedGlyphs(CGContextRef ctx, NSArray<NSDictionary *> *records,
                                  CGFloat quoteShift, int component) {
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    for (NSDictionary *record in records) {
        CFIndex count = [record[@"count"] longValue], selected = 0;
        const CGGlyph *rawGlyphs = [record[@"glyphs"] bytes];
        const CGPoint *rawPositions = [record[@"positions"] bytes];
        const CFIndex *indices = [record[@"stringIndices"] bytes];
        CGGlyph *glyphs = calloc((size_t)count, sizeof(CGGlyph));
        CGPoint *positions = calloc((size_t)count, sizeof(CGPoint));
        for (CFIndex i = 0; i < count; i++) {
            BOOL opening = indices[i] == 0;
            if ((component == 1 && !opening) || (component == 2 && opening)) continue;
            glyphs[selected] = rawGlyphs[i];
            positions[selected] = rawPositions[i];
            if (opening) positions[selected].x += quoteShift;
            selected++;
        }
        if (selected) CTFontDrawGlyphs((__bridge CTFontRef)record[@"font"], glyphs, positions, selected, ctx);
        free(glyphs); free(positions);
    }
}

static NSDictionary *FCRasterBounds(NSArray<NSDictionary *> *records, CGFloat quoteShift, int component) {
    const CGFloat scale = 4, width = 220, height = 50;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)(width * scale), (size_t)(height * scale),
        8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return @{ @"hasInk": @NO };
    CGContextScaleCTM(ctx, scale, scale);
    CGContextTranslateCTM(ctx, FCMargin, 25);
    FCDrawExtractedGlyphs(ctx, records, quoteShift, component);
    const unsigned char *pixels = CGBitmapContextGetData(ctx);
    size_t stride = CGBitmapContextGetBytesPerRow(ctx), low = SIZE_MAX, high = 0;
    BOOL found = NO;
    for (size_t y = 0; y < (size_t)(height * scale); y++) {
        for (size_t x = 0; x < (size_t)(width * scale); x++) {
            if (pixels[y * stride + x * 4 + 3] >= 40) {
                found = YES; low = MIN(low, x); high = MAX(high, x);
            }
        }
    }
    CGContextRelease(ctx);
    return found ? @{ @"hasInk": @YES, @"leftXPoints": @((double)low / scale - FCMargin),
        @"rightXPoints": @((double)(high + 1) / scale - FCMargin), @"rasterScale": @(scale) }
        : @{ @"hasInk": @NO, @"rasterScale": @(scale) };
}

static BOOL FCGlyphPNG(NSString *path, NSArray<NSDictionary *> *records, CGFloat quoteAdvance) {
    const CGFloat scale = 4, width = 220, height = 145;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)(width * scale), (size_t)(height * scale),
        8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return NO;
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, width * scale, height * scale));
    CGContextScaleCTM(ctx, scale, scale);
    CGContextSetRGBStrokeColor(ctx, .7, .7, .7, 1);
    CGContextSetLineWidth(ctx, .5);
    CGContextMoveToPoint(ctx, FCMargin, 0); CGContextAddLineToPoint(ctx, FCMargin, height);
    CGContextStrokePath(ctx);
    for (NSUInteger i = 0; i < 3; i++) {
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, FCMargin, height - 30 - i * 40);
        FCDrawExtractedGlyphs(ctx, records, -quoteAdvance * ((CGFloat)i / 2), 0);
        CGContextRestoreGState(ctx);
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx); CGContextRelease(ctx);
    if (!image) return NO;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image]; CGImageRelease(image);
    return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

static BOOL FCBoundary(NSString *source, NSUInteger offset, NSSet<NSNumber *> *approved, NSString **reason) {
    if (offset == 0 || offset >= source.length) { *reason = @"offset is not an interior UTF-16 boundary"; return NO; }
    if (![approved containsObject:@(offset)]) { *reason = @"offset is outside caller approved break set"; return NO; }
    NSRange before = [source rangeOfComposedCharacterSequenceAtIndex:offset - 1];
    NSRange after = [source rangeOfComposedCharacterSequenceAtIndex:offset];
    if (NSMaxRange(before) != offset || after.location != offset) {
        *reason = @"offset splits a composed character sequence"; return NO;
    }
    return YES;
}

static NSDictionary *FCExactBreak(CTFontRef font, NSString *directory) {
    NSString *source = @"extraordinary";
    NSUInteger split = 5;
    NSString *reason = nil;
    BOOL valid = FCBoundary(source, split, [NSSet setWithObject:@5], &reason);
    NSAttributedString *a = FCText(source, font, nil, NULL);
    CTTypesetterRef setter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)a);
    CTLineRef first = valid ? CTTypesetterCreateLine(setter, CFRangeMake(0, 5)) : NULL;
    CTLineRef second = valid ? CTTypesetterCreateLine(setter, CFRangeMake(5, 8)) : NULL;
    BOOL exact = first && second && CTLineGetStringRange(first).location == 0 &&
        CTLineGetStringRange(first).length == 5 && CTLineGetStringRange(second).location == 5 &&
        CTLineGetStringRange(second).length == 8;
    NSString *image = @"exact-break.png";
    BOOL drawn = exact && FCPNG([directory stringByAppendingPathComponent:image],
        @[(__bridge id)first, (__bridge id)second], @[@0, @0], @[@1, @1], 110, 110);
    NSDictionary *result = @{ @"id": @"explicit-source-ranges", @"status": exact && drawn ? @"pass" : @"fail",
        @"source": source, @"approvedBreakUTF16": @[@5], @"requestedRangesUTF16": @[@[@0,@5], @[@5,@8]],
        @"actualRangesUTF16": first && second ? @[@[@(CTLineGetStringRange(first).location), @(CTLineGetStringRange(first).length)],
          @[@(CTLineGetStringRange(second).location), @(CTLineGetStringRange(second).length)]] : @[],
        @"sourceCoverageComplete": @(exact), @"boundaryAccepted": @(valid), @"boundaryReason": reason ?: @"approved grapheme boundary",
        @"lines": first && second ? @[FCMetrics(first, 0, 1), FCMetrics(second, 0, 1)] : @[],
        @"image": image, @"imageWritten": @(drawn),
        @"claim": @"Caller supplied exact UTF-16 ranges to CTTypesetterCreateLine; Core Text shaped each intact line." };
    if (first) CFRelease(first); if (second) CFRelease(second); CFRelease(setter);
    return result;
}

static NSDictionary *FCDiscretionary(CTFontRef font, NSString *directory) {
    NSString *source = @"extraordinary";
    NSString *reason = nil;
    BOOL approved = FCBoundary(source, 5, [NSSet setWithObject:@5], &reason);
    // The visible first line is a derived attributed line. The source stays unchanged.
    NSString *visibleFirst = [[source substringToIndex:5] stringByAppendingString:@"-"];
    NSString *visibleSecond = [source substringFromIndex:5];
    CTLineRef first = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(visibleFirst, font, nil, NULL));
    CTLineRef second = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(visibleSecond, font, nil, NULL));
    BOOL displayed = FCPNG([directory stringByAppendingPathComponent:@"discretionary-hyphen.png"],
        @[(__bridge id)first, (__bridge id)second], @[@0, @0], @[@1, @1], 100, 100);
    NSDictionary *result = @{ @"id": @"caller-discretionary-hyphen", @"status": approved && displayed ? @"pass" : @"fail",
        @"logicalSource": source, @"sourceUTF16Length": @(source.length), @"approvedBreakUTF16": @[@5],
        @"renderedLines": @[visibleFirst, visibleSecond], @"derivedLineSourceMap": @[
            @{ @"line": @1, @"renderedRangeUTF16": @[@0,@5], @"sourceRangeUTF16": @[@0,@5] },
            @{ @"line": @1, @"renderedRangeUTF16": @[@5,@1], @"sourceRangeUTF16": [NSNull null], @"role": @"discretionary prebreak hyphen" },
            @{ @"line": @2, @"renderedRangeUTF16": @[@0,@8], @"sourceRangeUTF16": @[@5,@8] }],
        @"originalSourcePreserved": @([source isEqualToString:@"extraordinary"]),
        @"lines": @[FCMetrics(first, 0, 1), FCMetrics(second, 0, 1)],
        @"image": @"discretionary-hyphen.png", @"imageWritten": @(displayed),
        @"claim": @"The caller inserts a visible hyphen in a derived first line after selecting an approved break; the logical source has no hyphen." };
    CFRelease(first); CFRelease(second); return result;
}

static NSDictionary *FCRejections(void) {
    NSString *reason1 = nil, *reason2 = nil;
    BOOL unapproved = FCBoundary(@"extraordinary", 3, [NSSet setWithObject:@5], &reason1);
    NSString *clustered = @"a\u0301bc";
    BOOL midpoint = FCBoundary(clustered, 1, [NSSet setWithObject:@1], &reason2);
    return @{ @"id": @"reject-invalid-breaks", @"status": !unapproved && !midpoint ? @"pass" : @"fail",
        @"attempts": @[@{ @"source": @"extraordinary", @"requestedBreakUTF16": @3,
                            @"approvedBreakUTF16": @[@5], @"accepted": @(unapproved), @"reason": reason1 ?: @"" },
                          @{ @"source": clustered, @"requestedBreakUTF16": @1,
                             @"approvedBreakUTF16": @[@1], @"accepted": @(midpoint), @"reason": reason2 ?: @"" }],
        @"typesetterCalledForRejectedInputs": @NO,
        @"claim": @"Caller validation rejects an unapproved break and a composed-cluster midpoint before line creation." };
}

static NSDictionary *FCOverfull(CTFontRef font, NSString *directory) {
    NSString *source = @"MMMMMMMM"; CGFloat measure = 20;
    CTTypesetterRef setter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, NULL));
    CTLineRef line = CTTypesetterCreateLine(setter, CFRangeMake(0, source.length));
    double advance = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CFRange actual = CTLineGetStringRange(line);
    BOOL overfull = advance > measure && actual.location == 0 && (NSUInteger)actual.length == source.length;
    BOOL drawn = FCPNG([directory stringByAppendingPathComponent:@"overfull.png"],
        @[(__bridge id)line], @[@0], @[@1], measure, measure);
    NSDictionary *r = @{ @"id": @"explicit-overfull-line", @"status": overfull && drawn ? @"pass" : @"fail",
        @"source": source, @"requestedRangeUTF16": @[@0,@(source.length)],
        @"actualRangeUTF16": @[@(actual.location), @(actual.length)], @"measurePoints": @(measure),
        @"advancePoints": @(advance), @"overflowPoints": @(advance - measure), @"overfull": @(overfull),
        @"line": FCMetrics(line, 0, 1), @"image": @"overfull.png", @"imageWritten": @(drawn),
        @"claim": @"An exact line may exceed the requested measure. The caller reports overflow; no automatic rebreak occurs." };
    CFRelease(line); CFRelease(setter); return r;
}

static NSDictionary *FCTracking(CTFontRef font, NSString *directory) {
    NSString *source = @"HHHH";
    CTLineRef zero = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, @0, NULL));
    CTLineRef half = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, @0.5, NULL));
    double o0 = CTLineGetOffsetForStringIndex(zero, 3, NULL);
    double o1 = CTLineGetOffsetForStringIndex(half, 3, NULL);
    double delta = o1 - o0;
    NSMutableArray *caretOffsets = [NSMutableArray array];
    for (NSUInteger i = 0; i <= source.length; i++)
        [caretOffsets addObject:@[@(CTLineGetOffsetForStringIndex(zero, (CFIndex)i, NULL)),
                                  @(CTLineGetOffsetForStringIndex(half, (CFIndex)i, NULL))]];
    NSMutableArray *glyphPositions = [NSMutableArray array];
    for (id lineObject in @[(__bridge id)zero, (__bridge id)half]) {
        CTLineRef current = (__bridge CTLineRef)lineObject;
        CTRunRef run = (__bridge CTRunRef)((__bridge NSArray *)CTLineGetGlyphRuns(current)).firstObject;
        CFIndex count = CTRunGetGlyphCount(run);
        CGPoint *positions = calloc((size_t)count, sizeof(CGPoint));
        CTRunGetPositions(run, CFRangeMake(0, 0), positions);
        NSMutableArray *values = [NSMutableArray array];
        for (CFIndex i = 0; i < count; i++) [values addObject:@(positions[i].x)];
        free(positions);
        [glyphPositions addObject:values];
    }
    double glyphDelta = [glyphPositions[1][3] doubleValue] - [glyphPositions[0][3] doubleValue];
    BOOL within = fabs(glyphDelta - 1.5) <= .05;
    BOOL drawn = FCPNG([directory stringByAppendingPathComponent:@"tracking.png"],
        @[(__bridge id)zero, (__bridge id)half], @[@0,@0], @[@1,@1], 100, 100);
    NSDictionary *r = @{ @"id": @"fixed-tracking", @"status": within && drawn ? @"pass" : @"fail",
        @"text": source, @"trackingValuesPoints": @[@0,@0.5], @"measuredOffsetAtUTF16Index3Points": @[@(o0),@(o1)],
        @"caretOffsetDeltaPoints": @(delta), @"caretOffsetsByUTF16IndexPoints": caretOffsets,
        @"glyphOriginsPoints": glyphPositions, @"glyphOriginAtIndex3DeltaPoints": @(glyphDelta),
        @"expectedGlyphOriginDeltaPoints": @1.5, @"tolerancePoints": @0.05,
        @"lines": @[FCMetrics(zero, 0, 1), FCMetrics(half, 0, 1)],
        @"image": @"tracking.png", @"imageWritten": @(drawn),
        @"claim": @"A caller supplied fixed kCTTrackingAttributeName value moves the fourth glyph origin by three 0.5 pt intervals. Core Text caret offset is reported separately." };
    CFRelease(zero); CFRelease(half); return r;
}

static NSDictionary *FCHanging(CTFontRef font, NSString *directory) {
    NSString *source = @"“Quoted words”";
    CTLineBoundsOptions none = 0, hanging = kCTLineBoundsUseHangingPunctuation;
    CTParagraphStyleSetting setting0 = { kCTParagraphStyleSpecifierLineBoundsOptions, sizeof(none), &none };
    CTParagraphStyleSetting setting1 = { kCTParagraphStyleSpecifierLineBoundsOptions, sizeof(hanging), &hanging };
    CTParagraphStyleRef style0 = CTParagraphStyleCreate(&setting0, 1), style1 = CTParagraphStyleCreate(&setting1, 1);
    CTLineRef line0 = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, style0));
    CTLineRef line1 = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, style1));
    CGRect plain = CTLineGetBoundsWithOptions(line0, 0);
    CGRect option = CTLineGetBoundsWithOptions(line1, kCTLineBoundsUseHangingPunctuation);
    CGRect ink0 = CTLineGetImageBounds(line0, NULL), ink1 = CTLineGetImageBounds(line1, NULL);
    // Also measure the actual frame origins under the paragraph style setting.
    NSMutableArray *frameOrigins = [NSMutableArray array];
    for (id styleObject in @[(__bridge id)style0, (__bridge id)style1]) {
        CTParagraphStyleRef style = (__bridge CTParagraphStyleRef)styleObject;
        CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, style));
        CGMutablePathRef path = CGPathCreateMutable(); CGPathAddRect(path, NULL, CGRectMake(0, 0, 120, 60));
        CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
        CGPoint origin = CGPointZero;
        if (CFArrayGetCount(CTFrameGetLines(frame))) CTFrameGetLineOrigins(frame, CFRangeMake(0, 1), &origin);
        [frameOrigins addObject:@{ @"x": @(origin.x), @"y": @(origin.y),
            @"lineCount": @(CFArrayGetCount(CTFrameGetLines(frame))) }];
        CFRelease(frame); CGPathRelease(path); CFRelease(setter);
    }
    double quoteWidth = CTLineGetOffsetForStringIndex(line0, 1, NULL);
    double inkShift = ink1.origin.x - ink0.origin.x;
    BOOL changed = quoteWidth > 0 && fabs(inkShift + quoteWidth) < .05 &&
        fabs([frameOrigins[0][@"x"] doubleValue] - [frameOrigins[1][@"x"] doubleValue]) < .05;
    BOOL drawn = FCPNG([directory stringByAppendingPathComponent:@"hanging-built-in.png"],
        @[(__bridge id)line0, (__bridge id)line1], @[@0,@0], @[@1,@1], 120, 120);
    NSDictionary *r = @{ @"id": @"built-in-hanging-punctuation", @"status": changed && drawn ? @"pass" : @"fail",
        @"text": source, @"paragraphStyleSpecifier": @"kCTParagraphStyleSpecifierLineBoundsOptions",
        @"option": @"kCTLineBoundsUseHangingPunctuation", @"frameOriginsPoints": frameOrigins,
        @"plainLineBoundsPoints": FCBox(plain), @"hangingOptionLineBoundsPoints": FCBox(option),
        @"plainInkBoundsPoints": FCBox(ink0), @"optionInkBoundsPoints": FCBox(ink1),
        @"measuredOpeningQuoteAdvancePoints": @(quoteWidth), @"observedInkLeftShiftPoints": @(inkShift),
        @"expectedInkLeftShiftPoints": @(-quoteWidth), @"tolerancePoints": @0.05,
        @"lineOriginDeltaXPoints": @([frameOrigins[1][@"x"] doubleValue] - [frameOrigins[0][@"x"] doubleValue]),
        @"image": @"hanging-built-in.png", @"imageWritten": @(drawn),
        @"claim": @"Core Text exposes a hanging punctuation bounds option; measured frame origins and ink bounds record what it did for this fixture. No caller percentage is claimed." };
    CFRelease(line0); CFRelease(line1); CFRelease(style0); CFRelease(style1); return r;
}

static NSDictionary *FCCustomProtrusion(CTFontRef font, NSString *directory) {
    NSString *source = @"“Quoted words”";
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, NULL));
    double quoteWidth = CTLineGetOffsetForStringIndex(line, 1, NULL) - CTLineGetOffsetForStringIndex(line, 0, NULL);
    NSArray *fractions = @[@0,@0.5,@1];
    NSMutableArray *samples = [NSMutableArray array], *origins = [NSMutableArray array];
    for (NSNumber *fraction in fractions) {
        double x = -quoteWidth * fraction.doubleValue;
        [samples addObject:@{ @"requestedProtrusionFraction": fraction,
            @"measuredOpeningQuoteAdvancePoints": @(quoteWidth), @"chosenOriginXPoints": @(x),
            @"line": FCMetrics(line, x, 1) }];
        [origins addObject:@(x)];
    }
    BOOL finite = isfinite(quoteWidth) && quoteWidth > 0;
    CGRect rawInk = CTLineGetImageBounds(line, NULL);
    for (NSUInteger i = 0; i < fractions.count; i++) {
        double requestedOrigin = -quoteWidth * [fractions[i] doubleValue];
        NSDictionary *sample = samples[i];
        double chosenOrigin = [sample[@"chosenOriginXPoints"] doubleValue];
        double resultingLeftInk = [sample[@"line"][@"inkBoundsAtOriginPoints"][@"x"] doubleValue];
        finite = finite && fabs(chosenOrigin - requestedOrigin) < .001 &&
            fabs(resultingLeftInk - (rawInk.origin.x + requestedOrigin)) < .001;
    }
    BOOL drawn = FCPNG([directory stringByAppendingPathComponent:@"caller-protrusion.png"],
        @[(__bridge id)line, (__bridge id)line, (__bridge id)line], origins, @[@1,@1,@1], 120, 120);
    NSDictionary *r = @{ @"id": @"caller-opening-quote-protrusion", @"status": finite && drawn ? @"demonstrated" : @"fail",
        @"text": source, @"samples": samples, @"image": @"caller-protrusion.png", @"imageWritten": @(drawn),
        @"constructedOriginAndInkEquation": @(finite),
        @"claim": @"Folio shifts an intact shaped line by 0, 50, or 100 percent of the measured opening quote advance. This moves the interior text with the quote; a fixed interior anchor needs further caller layout work." };
    CFRelease(line); return r;
}

static NSDictionary *FCQuoteOnlyGlyphPositioning(CTFontRef font, NSString *directory) {
    NSString *source = @"“Quoted words”";
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, font, nil, NULL));
    NSArray<NSDictionary *> *runs = FCExtractRuns(line);
    double quoteAdvance = CTLineGetOffsetForStringIndex(line, 1, NULL) - CTLineGetOffsetForStringIndex(line, 0, NULL);
    NSMutableArray *runEvidence = [NSMutableArray array];
    NSUInteger quoteGlyphs = 0, interiorGlyphs = 0;
    for (NSDictionary *run in runs) {
        CFIndex count = [run[@"count"] longValue];
        const CGGlyph *glyphs = [run[@"glyphs"] bytes];
        const CGPoint *positions = [run[@"positions"] bytes];
        const CFIndex *indices = [run[@"stringIndices"] bytes];
        NSMutableArray *glyphEvidence = [NSMutableArray array];
        for (CFIndex i = 0; i < count; i++) {
            BOOL opening = indices[i] == 0;
            if (opening) quoteGlyphs++; else interiorGlyphs++;
            [glyphEvidence addObject:@{ @"glyphID": @(glyphs[i]), @"stringIndexUTF16": @(indices[i]),
                @"positionXPoints": @(positions[i].x), @"positionYPoints": @(positions[i].y),
                @"openingQuote": @(opening) }];
        }
        NSString *name = CFBridgingRelease(CTFontCopyPostScriptName((__bridge CTFontRef)run[@"font"]));
        [runEvidence addObject:@{ @"fontPostScriptName": name, @"glyphs": glyphEvidence }];
    }
    NSDictionary *baselineQuote = FCRasterBounds(runs, 0, 1);
    NSDictionary *baselineInterior = FCRasterBounds(runs, 0, 2);
    NSArray *fractions = @[@0,@0.5,@1];
    NSMutableArray *samples = [NSMutableArray array];
    BOOL measured = isfinite(quoteAdvance) && quoteAdvance > 0 && quoteGlyphs == 1 && interiorGlyphs > 0 &&
        [baselineQuote[@"hasInk"] boolValue] && [baselineInterior[@"hasInk"] boolValue];
    for (NSNumber *fraction in fractions) {
        double shift = -quoteAdvance * fraction.doubleValue;
        NSDictionary *quote = FCRasterBounds(runs, shift, 1);
        NSDictionary *interior = FCRasterBounds(runs, shift, 2);
        double quoteDelta = [quote[@"leftXPoints"] doubleValue] - [baselineQuote[@"leftXPoints"] doubleValue];
        double interiorLeftDelta = [interior[@"leftXPoints"] doubleValue] - [baselineInterior[@"leftXPoints"] doubleValue];
        double interiorRightDelta = [interior[@"rightXPoints"] doubleValue] - [baselineInterior[@"rightXPoints"] doubleValue];
        measured = measured && [quote[@"hasInk"] boolValue] && [interior[@"hasInk"] boolValue] &&
            fabs(quoteDelta - shift) <= .35 && fabs(interiorLeftDelta) <= .001 && fabs(interiorRightDelta) <= .001;
        [samples addObject:@{ @"requestedProtrusionFraction": fraction, @"requestedQuoteShiftPoints": @(shift),
            @"rasterQuoteBoundsPoints": quote, @"rasterInteriorBoundsPoints": interior,
            @"observedQuoteLeftShiftPoints": @(quoteDelta), @"observedInteriorLeftShiftPoints": @(interiorLeftDelta),
            @"observedInteriorRightShiftPoints": @(interiorRightDelta) }];
    }
    NSString *image = @"quote-only-glyph-positioning.png";
    BOOL drawn = FCGlyphPNG([directory stringByAppendingPathComponent:image], runs, quoteAdvance);
    NSDictionary *result = @{ @"id": @"quote-only-glyph-positioning", @"status": measured && drawn ? @"pass" : @"fail",
        @"text": source, @"measuredOpeningQuoteAdvancePoints": @(quoteAdvance),
        @"sourceLineGlyphRuns": runEvidence, @"openingQuoteGlyphCount": @(quoteGlyphs),
        @"interiorGlyphCount": @(interiorGlyphs), @"samples": samples,
        @"rasterPositionTolerancePoints": @0.35, @"rasterScale": @4,
        @"image": image, @"imageWritten": @(drawn),
        @"claim": @"The caller repositions only the opening quote glyph extracted from a fully shaped Core Text line. Separate 4x raster bounds verify the quote moves by the requested amount while all interior glyph ink remains fixed. This is Folio-owned glyph drawing, without text hit-testing or selection integration." };
    CFRelease(line); return result;
}

static NSDictionary *FCExpansion(CTFontRef font, NSString *directory) {
    NSString *source = @"Harmonious";
    NSArray *factors = @[@0.98,@1,@1.02];
    NSMutableArray *samples = [NSMutableArray array], *lines = [NSMutableArray array], *advances = [NSMutableArray array];
    for (NSNumber *factor in factors) {
        CGAffineTransform matrix = CGAffineTransformMakeScale(factor.doubleValue, 1);
        CTFontRef variant = CTFontCreateCopyWithAttributes(font, 0, &matrix, NULL);
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)FCText(source, variant, nil, NULL));
        [lines addObject:(__bridge id)line];
        [advances addObject:@(CTLineGetTypographicBounds(line, NULL, NULL, NULL))];
        [samples addObject:@{ @"requestedHorizontalScale": factor,
            @"fontMatrixA": @(matrix.a), @"line": FCMetrics(line, 0, 1) }];
        CFRelease(line); CFRelease(variant);
    }
    double baseline = [advances[1] doubleValue];
    BOOL scaled = baseline > 0;
    for (NSUInteger i = 0; i < factors.count; i++)
        scaled = scaled && fabs([advances[i] doubleValue] - baseline * [factors[i] doubleValue]) < .05;
    BOOL drawn = FCPNG([directory stringByAppendingPathComponent:@"horizontal-expansion.png"],
        lines, @[@0,@0,@0], @[@1,@1,@1], 120, 120);
    NSDictionary *r = @{ @"id": @"bounded-horizontal-expansion", @"status": drawn && scaled ? @"pass" : @"fail",
        @"text": source, @"samples": samples, @"image": @"horizontal-expansion.png", @"imageWritten": @(drawn),
        @"advanceMatchesRequestedScaleWithinPoints": @0.05,
        @"claim": @"A caller supplied CTFont matrix scales intact Core Text line shaping to 98, 100, or 102 percent; the resulting Core Text advances and ink bounds are measured from each variant." };
    return r;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3 || strcmp(argv[1], "--output") != 0) {
            fprintf(stderr, "usage: coretext-controls --output directory\n"); return 2;
        }
        NSString *directory = @(argv[2]); NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            fprintf(stderr, "output: %s\n", error.localizedDescription.UTF8String); return 2;
        }
        CTFontRef font = FCFont();
        NSString *name = CFBridgingRelease(CTFontCopyPostScriptName(font));
        if (![name isEqualToString:@"Times-Roman"]) { fprintf(stderr, "Times-Roman resolved to %s\n", name.UTF8String); CFRelease(font); return 2; }
        CFStringRef version = CTFontCopyName(font, kCTFontVersionNameKey);
        struct utsname system; uname(&system);
        NSArray *cases = @[FCExactBreak(font, directory), FCDiscretionary(font, directory),
            FCRejections(), FCOverfull(font, directory), FCTracking(font, directory),
            FCHanging(font, directory), FCCustomProtrusion(font, directory),
            FCQuoteOnlyGlyphPositioning(font, directory), FCExpansion(font, directory)];
        BOOL pass = YES;
        for (NSDictionary *item in cases) if ([item[@"status"] isEqualToString:@"fail"]) pass = NO;
        NSDictionary *result = @{ @"schemaVersion": @1, @"engine": @"CoreText caller controls", @"allAssertionsPassed": @(pass),
            @"environment": @{ @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString,
                @"kernel": @(system.release), @"machine": @(system.machine), @"sdkVersion": @(__MAC_OS_X_VERSION_MAX_ALLOWED),
                @"pointSize": @(FCSize), @"rasterScale": @(FCScale) },
            @"font": @{ @"postScriptName": name, @"version": version ? (__bridge NSString *)version : @"unknown" },
            @"scope": @"Simple left-to-right Latin-script fixture. The caller provides breaks and drawing choices; Core Text shapes intact lines.",
            @"limits": @[
                @"The caller must compute and approve break opportunities, penalties, discretionary substitutions, line widths, tracking, and protrusion. This probe does not implement paragraph or page optimization.",
                @"The derived discretionary line is a proof for extraordinary only. Its source map does not prove general hyphenation, selection, copy, accessibility, or complex-script shaping across breaks.",
                @"Font-matrix expansion is an observed microprimitive, not evidence of acceptable typography or shaping for math, bidirectional text, or arbitrary scripts.",
                @"Built-in hanging punctuation is an option with observed bounds. The caller-controlled percentage is tested only for the simple quote fixture using Folio-owned glyph drawing; selection and hit-testing are unimplemented." ],
            @"cases": cases };
        if (version) CFRelease(version); CFRelease(font);
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (!data || ![data writeToFile:[directory stringByAppendingPathComponent:@"results.json"] atomically:YES]) {
            fprintf(stderr, "results: %s\n", error.localizedDescription.UTF8String ?: "write failed"); return 1;
        }
        printf("Core Text controls: %lu cases, assertions %s\n", (unsigned long)cases.count, pass ? "passed" : "failed");
        return pass ? 0 : 1;
    }
}
