// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWEditorViewController.h"
#import "../FWManuscript/FWWork.h"
#import <FolioKit/FolioKit.h>

static NSAttributedStringKey const FWMeaning = @"FolioTextMeaning";
static NSAttributedStringKey const FWAppearance = @"FolioTextAppearance";
static NSAttributedStringKey const FWParagraphIdentity = @"FolioParagraphIdentity";
static NSPasteboardType const FWTextPasteboardType = @"dev.foliosuite.text-fragment-v1";

static NSTextAlignment FWNativeAlignment(FKParagraphAlignment alignment) {
    switch (alignment) {
        case FKParagraphAlignmentLeft: return NSTextAlignmentLeft;
        case FKParagraphAlignmentCenter: return NSTextAlignmentCenter;
        case FKParagraphAlignmentRight: return NSTextAlignmentRight;
        case FKParagraphAlignmentJustified: return NSTextAlignmentJustified;
        default: return NSTextAlignmentNatural;
    }
}

static FKParagraphAlignment FWModelAlignment(NSTextAlignment alignment) {
    switch (alignment) {
        case NSTextAlignmentLeft: return FKParagraphAlignmentLeft;
        case NSTextAlignmentCenter: return FKParagraphAlignmentCenter;
        case NSTextAlignmentRight: return FKParagraphAlignmentRight;
        case NSTextAlignmentJustified: return FKParagraphAlignmentJustified;
        default: return FKParagraphAlignmentNatural;
    }
}

static NSFont *FWFont(NSUInteger meaning, NSUInteger appearance) {
    NSFont *font = [NSFont fontWithName:@"Times New Roman" size:18] ?: [NSFont systemFontOfSize:18];
    NSFontTraitMask traits = 0;
    if ((meaning & FKTextMeaningStrongEmphasis) || (appearance & FKTextAppearanceBold)) traits |= NSBoldFontMask;
    if ((meaning & FKTextMeaningEmphasis) || (appearance & FKTextAppearanceItalic)) traits |= NSItalicFontMask;
    return [NSFontManager.sharedFontManager convertFont:font toHaveTrait:traits];
}

static NSDictionary *FWAttributes(NSUInteger meaning, NSUInteger appearance, FKParagraphAlignment alignment) {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = FWNativeAlignment(alignment);
    style.paragraphSpacing = 10;
    return @{FWMeaning:@(meaning), FWAppearance:@(appearance),
             NSFontAttributeName:FWFont(meaning, appearance),
             NSForegroundColorAttributeName:NSColor.textColor, NSParagraphStyleAttributeName:style};
}

@interface FWTextView : NSTextView
@property (nonatomic, weak) FWEditorViewController *editor;
@end

@implementation FWTextView
- (void)toggleEmphasis:(id)sender { [self.editor toggleEmphasis:sender]; }
- (void)toggleStrongEmphasis:(id)sender { [self.editor toggleStrongEmphasis:sender]; }
- (void)toggleBold:(id)sender { [self.editor toggleBold:sender]; }
- (void)toggleItalic:(id)sender { [self.editor toggleItalic:sender]; }
- (void)clearFormatting:(id)sender { [self.editor clearFormatting:sender]; }

// Internal copy-paste preserves supported meaning, but never copies object identity.
// External paste deliberately accepts plain text until rich-text import is specified.
- (NSArray<NSPasteboardType> *)readablePasteboardTypes { return @[FWTextPasteboardType, NSPasteboardTypeString]; }
- (NSArray<NSPasteboardType> *)writablePasteboardTypes { return @[FWTextPasteboardType, NSPasteboardTypeString]; }
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pasteboard type:(NSPasteboardType)type {
    if (![type isEqual:FWTextPasteboardType]) return [super writeSelectionToPasteboard:pasteboard type:type];
    NSMutableArray *runs = [NSMutableArray array];
    [self.textStorage enumerateAttributesInRange:self.selectedRange options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSParagraphStyle *style = attributes[NSParagraphStyleAttributeName];
        [runs addObject:@{@"text":[self.string substringWithRange:range], @"meaning":attributes[FWMeaning] ?: @0,
                         @"appearance":attributes[FWAppearance] ?: @0, @"alignment":@(FWModelAlignment(style.alignment))}];
    }];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:runs format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    return data && [pasteboard setData:data forType:type];
}
- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pasteboard type:(NSPasteboardType)type {
    if (![type isEqual:FWTextPasteboardType]) return [super readSelectionFromPasteboard:pasteboard type:type];
    NSData *data = [pasteboard dataForType:type];
    id runs = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
    if (![runs isKindOfClass:NSArray.class]) return NO;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    for (id run in runs) {
        if (![run isKindOfClass:NSDictionary.class] || ![run[@"text"] isKindOfClass:NSString.class]) return NO;
        for (NSString *key in @[@"meaning", @"appearance", @"alignment"]) if (![run[key] isKindOfClass:NSNumber.class]) return NO;
        NSUInteger meaning = [run[@"meaning"] unsignedIntegerValue], appearance = [run[@"appearance"] unsignedIntegerValue];
        NSUInteger alignment = [run[@"alignment"] unsignedIntegerValue];
        if (meaning > 3 || appearance > 3 || alignment > FKParagraphAlignmentJustified) return NO;
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:run[@"text"] attributes:FWAttributes(meaning, appearance, alignment)]];
    }
    [self insertText:text replacementRange:self.selectedRange];
    return YES;
}
- (void)insertText:(id)insertString replacementRange:(NSRange)replacementRange {
    NSMutableAttributedString *text = [insertString isKindOfClass:NSAttributedString.class] ? [insertString mutableCopy] :
        [[NSMutableAttributedString alloc] initWithString:insertString attributes:self.typingAttributes];
    for (NSString *separator in @[@"\r\n", @"\r", @"\u2029"]) {
        NSRange range;
        while ((range = [text.string rangeOfString:separator]).location != NSNotFound) [text replaceCharactersInRange:range withString:@"\n"];
    }
    // A paste has no source identities. Keep the destination paragraph's identity;
    // captureText assigns new identities to any additional paragraphs it introduces.
    NSUInteger insertion = replacementRange.location == NSNotFound ? self.selectedRange.location : replacementRange.location;
    if (insertion <= self.string.length) {
        NSUInteger paragraph = [[self.string substringToIndex:insertion] componentsSeparatedByString:@"\n"].count - 1;
        NSArray<FKParagraph *> *paragraphs = self.editor.work.text.paragraphs;
        if (paragraph < paragraphs.count) [text addAttribute:FWParagraphIdentity value:paragraphs[paragraph].identifier range:NSMakeRange(0, text.length)];
    }
    [super insertText:text replacementRange:replacementRange];
}
@end

@interface FWEditorViewController () <NSTextViewDelegate>
@property (nonatomic, strong) NSTextView *textView;
@property (nonatomic, strong) NSUndoManager *editingUndoManager;
@property (nonatomic, copy) NSString *trailingParagraphIdentifier;
@property (nonatomic) BOOL loading;
@property (nonatomic, strong) NSPopUpButton *alignmentButton;
@end

@implementation FWEditorViewController
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _work = work;
        _editingUndoManager = undoManager;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didFinishUndoOrRedo:)
            name:NSUndoManagerDidUndoChangeNotification object:undoManager];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didFinishUndoOrRedo:)
            name:NSUndoManagerDidRedoChangeNotification object:undoManager];
    }
    return self;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)didFinishUndoOrRedo:(NSNotification *)notification {
    // AppKit can restore text after its last textDidChange callback in an undo group.
    // Reconcile only after the whole operation; NSDocument owns undo's change count.
    if (self.isViewLoaded && !self.loading) [self captureText];
}
- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    NSStackView *tools = [NSStackView new];
    tools.spacing = 8;
    tools.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *titles = @[@"Emphasis", @"Strong", @"Bold", @"Italic"];
    NSArray *actions = @[@"toggleEmphasis:", @"toggleStrongEmphasis:", @"toggleBold:", @"toggleItalic:"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSButton *button = [NSButton buttonWithTitle:titles[i] target:self action:NSSelectorFromString(actions[i])];
        button.toolTip = i < 2 ? @"Express meaning; its appearance can change with the publication style." : @"Apply an explicit typographic choice.";
        [button setAccessibilityLabel:i == 1 ? @"Strong emphasis" : titles[i]];
        [tools addArrangedSubview:button];
    }
    self.alignmentButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.alignmentButton addItemsWithTitles:@[@"Natural", @"Left", @"Center", @"Right", @"Justified"]];
    [self.alignmentButton setAccessibilityLabel:@"Paragraph alignment"];
    self.alignmentButton.target = self;
    self.alignmentButton.action = @selector(changeParagraphAlignment:);
    [tools addArrangedSubview:self.alignmentButton];
    [self.view addSubview:tools];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    FWTextView *text = [[FWTextView alloc] initWithFrame:scroll.contentView.bounds];
    text.editor = self;
    text.delegate = self;
    text.richText = YES;
    text.importsGraphics = NO;
    text.usesFontPanel = NO;
    text.usesRuler = NO;
    text.allowsUndo = YES;
    text.verticallyResizable = YES;
    text.horizontallyResizable = NO;
    text.minSize = NSMakeSize(0, 0);
    text.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    text.autoresizingMask = NSViewWidthSizable;
    text.textContainer.containerSize = NSMakeSize(scroll.contentSize.width, CGFLOAT_MAX);
    text.textContainer.widthTracksTextView = YES;
    text.textContainerInset = NSMakeSize(32, 28);
    text.automaticQuoteSubstitutionEnabled = NO;
    text.automaticDashSubstitutionEnabled = NO;
    [text setAccessibilityLabel:@"Manuscript text"];
    text.identifier = @"manuscriptText";
    self.textView = text;
    scroll.documentView = text;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [tools.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [tools.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:12],
        [tools.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-16],
        [scroll.topAnchor constraintEqualToAnchor:tools.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self displayWork];
}
- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.textView];
}
- (void)setWork:(FWWork *)work {
    _work = work;
    if (self.isViewLoaded) [self displayWork];
}
- (void)displayWork {
    self.loading = YES;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    NSArray<FKParagraph *> *paragraphs = self.work.text.paragraphs;
    for (NSUInteger index = 0; index < paragraphs.count; index++) {
        FKParagraph *p = paragraphs[index];
        NSUInteger start = text.length;
        for (FKTextRun *run in p.runs) [text appendAttributedString:[[NSAttributedString alloc] initWithString:run.string attributes:FWAttributes(run.meaning, run.appearance, p.alignment)]];
        if (index + 1 < paragraphs.count) [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:FWAttributes(0, 0, p.alignment)]];
        [text addAttribute:FWParagraphIdentity value:p.identifier range:NSMakeRange(start, text.length - start)];
    }
    [self.textView.textStorage setAttributedString:text];
    self.trailingParagraphIdentifier = paragraphs.lastObject.identifier;
    NSMutableDictionary *typing = [FWAttributes(0, 0, paragraphs.firstObject.alignment) mutableCopy];
    typing[FWParagraphIdentity] = paragraphs.firstObject.identifier;
    self.textView.typingAttributes = typing;
    [self.textView setSelectedRange:NSMakeRange(0, 0)];
    self.loading = NO;
}
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view { return self.editingUndoManager; }
- (void)textDidChange:(NSNotification *)notification {
    if (self.loading) return;
    [self captureText];
    if (self.textDidChange) self.textDidChange();
}
- (void)captureText {
    NSTextStorage *storage = self.textView.textStorage;
    NSArray<NSString *> *lines = [storage.string componentsSeparatedByString:@"\n"];
    NSMutableArray *paragraphs = [NSMutableArray array];
    NSMutableSet *identifiers = [NSMutableSet set];
    NSUInteger offset = 0;
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSRange content = NSMakeRange(offset, lines[i].length);
        NSRange whole = NSMakeRange(offset, content.length + (i + 1 < lines.count ? 1 : 0));
        NSDictionary *attributes = offset < storage.length ? [storage attributesAtIndex:offset effectiveRange:NULL] : self.textView.typingAttributes;
        // An empty text view has no attributes from which to recover identity.
        // Removing all text retains the first paragraph, not the old trailing one.
        NSString *identifier = whole.length ? attributes[FWParagraphIdentity] :
            (storage.length ? self.trailingParagraphIdentifier : self.work.text.paragraphs.firstObject.identifier);
        if (!identifier || [identifiers containsObject:identifier]) identifier = [FKIdentifiedObject new].identifier;
        [identifiers addObject:identifier];
        NSMutableArray *runs = [NSMutableArray array];
        [storage enumerateAttributesInRange:content options:0 usingBlock:^(NSDictionary *a, NSRange range, BOOL *stop) {
            [runs addObject:[[FKTextRun alloc] initWithString:[storage.string substringWithRange:range]
                meaning:[a[FWMeaning] unsignedIntegerValue] appearance:[a[FWAppearance] unsignedIntegerValue]]];
        }];
        NSParagraphStyle *style = attributes[NSParagraphStyleAttributeName];
        FKParagraphAlignment alignment = style ? FWModelAlignment(style.alignment) : FKParagraphAlignmentNatural;
        [paragraphs addObject:[[FKParagraph alloc] initWithIdentifier:identifier runs:runs alignment:alignment]];
        [storage addAttribute:FWParagraphIdentity value:identifier range:whole];
        offset += whole.length;
    }
    self.trailingParagraphIdentifier = [paragraphs.lastObject identifier];
    self.work.text = [[FKText alloc] initWithIdentifier:self.work.text.identifier paragraphs:paragraphs];
    if (self.textView.selectedRange.location == storage.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        attributes[FWParagraphIdentity] = self.trailingParagraphIdentifier;
        self.textView.typingAttributes = attributes;
    }
}
- (void)textViewDidChangeSelection:(NSNotification *)notification {
    if (self.loading) return;
    NSUInteger index = self.textView.selectedRange.location;
    NSParagraphStyle *style = index < self.textView.string.length ? [self.textView.textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL] : self.textView.typingAttributes[NSParagraphStyleAttributeName];
    [self.alignmentButton selectItemAtIndex:style ? FWModelAlignment(style.alignment) : FKParagraphAlignmentNatural];
}
- (void)toggleEmphasis:(id)sender { [self toggleKey:FWMeaning bit:FKTextMeaningEmphasis name:@"Emphasis"]; }
- (void)toggleStrongEmphasis:(id)sender { [self toggleKey:FWMeaning bit:FKTextMeaningStrongEmphasis name:@"Strong Emphasis"]; }
- (void)toggleBold:(id)sender { [self toggleKey:FWAppearance bit:FKTextAppearanceBold name:@"Bold"]; }
- (void)toggleItalic:(id)sender { [self toggleKey:FWAppearance bit:FKTextAppearanceItalic name:@"Italic"]; }
- (void)toggleKey:(NSString *)key bit:(NSUInteger)bit name:(NSString *)name {
    NSRange range = self.textView.selectedRange;
    if (!range.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        attributes[key] = @([attributes[key] unsignedIntegerValue] ^ bit);
        attributes[NSFontAttributeName] = FWFont([attributes[FWMeaning] unsignedIntegerValue], [attributes[FWAppearance] unsignedIntegerValue]);
        self.textView.typingAttributes = attributes;
        [self.view.window makeFirstResponder:self.textView];
        return;
    }
    __block BOOL remove = YES;
    [self.textView.textStorage enumerateAttribute:key inRange:range options:0 usingBlock:^(id value, NSRange r, BOOL *stop) {
        if (!([value unsignedIntegerValue] & bit)) remove = NO;
    }];
    [self editAttributesInRange:range name:name transform:^(NSMutableDictionary *attributes) {
        NSUInteger value = [attributes[key] unsignedIntegerValue];
        attributes[key] = @(remove ? value & ~bit : value | bit);
        attributes[NSFontAttributeName] = FWFont([attributes[FWMeaning] unsignedIntegerValue], [attributes[FWAppearance] unsignedIntegerValue]);
    }];
}
- (void)clearFormatting:(id)sender {
    if (!self.textView.selectedRange.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        attributes[FWMeaning] = @0;
        attributes[FWAppearance] = @0;
        attributes[NSFontAttributeName] = FWFont(0, 0);
        self.textView.typingAttributes = attributes;
        return;
    }
    [self editAttributesInRange:self.textView.selectedRange name:@"Clear Formatting" transform:^(NSMutableDictionary *attributes) {
        attributes[FWMeaning] = @0;
        attributes[FWAppearance] = @0;
        attributes[NSFontAttributeName] = FWFont(0, 0);
    }];
}
- (void)editAttributesInRange:(NSRange)range name:(NSString *)name transform:(void (^)(NSMutableDictionary *))transform {
    if (!range.length) return;
    NSRange selection = self.textView.selectedRange;
    NSAttributedString *before = [self.textView.textStorage attributedSubstringFromRange:range];
    NSMutableAttributedString *after = [before mutableCopy];
    [before enumerateAttributesInRange:NSMakeRange(0, before.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange subrange, BOOL *stop) {
        NSMutableDictionary *changed = [attributes mutableCopy];
        transform(changed);
        [after setAttributes:changed range:subrange];
    }];
    [self.textView breakUndoCoalescing];
    [self applyFormatting:after range:range actionName:name];
    [self.textView setSelectedRange:selection];
    [self.view.window makeFirstResponder:self.textView];
}
- (void)applyFormatting:(NSAttributedString *)text range:(NSRange)range actionName:(NSString *)name {
    NSAttributedString *previous = [self.textView.textStorage attributedSubstringFromRange:range];
    // AppKit does not supply undo for arbitrary custom attribute mutations.
    // Record the complete attribute snapshot, including semantic meaning and identity.
    [self.editingUndoManager registerUndoWithTarget:self handler:^(FWEditorViewController *editor) {
        [editor applyFormatting:previous range:range actionName:name];
    }];
    [self.textView.textStorage beginEditing];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange part, BOOL *stop) {
        [self.textView.textStorage setAttributes:attributes range:NSMakeRange(range.location + part.location, part.length)];
    }];
    [self.textView.textStorage endEditing];
    [self.textView didChangeText];
    [self.editingUndoManager setActionName:name];
}
- (void)applyEmptyParagraphAttributes:(NSDictionary *)attributes {
    NSDictionary *previous = self.textView.typingAttributes;
    [self.editingUndoManager registerUndoWithTarget:self handler:^(FWEditorViewController *editor) {
        [editor applyEmptyParagraphAttributes:previous];
    }];
    self.textView.typingAttributes = attributes;
    [self.textView didChangeText];
    [self.editingUndoManager setActionName:@"Paragraph Alignment"];
}
- (void)changeParagraphAlignment:(NSPopUpButton *)sender {
    NSTextAlignment alignment = FWNativeAlignment(sender.indexOfSelectedItem);
    NSRange range = [self.textView.string paragraphRangeForRange:self.textView.selectedRange];
    if (!range.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        NSMutableParagraphStyle *style = [attributes[NSParagraphStyleAttributeName] mutableCopy] ?: [NSMutableParagraphStyle new];
        style.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = style;
        [self applyEmptyParagraphAttributes:attributes];
    } else {
        [self editAttributesInRange:range name:@"Paragraph Alignment" transform:^(NSMutableDictionary *attributes) {
            NSMutableParagraphStyle *style = [attributes[NSParagraphStyleAttributeName] mutableCopy] ?: [NSMutableParagraphStyle new];
            style.alignment = alignment;
            attributes[NSParagraphStyleAttributeName] = style;
        }];
    }
    [self.view.window makeFirstResponder:self.textView];
}
@end
