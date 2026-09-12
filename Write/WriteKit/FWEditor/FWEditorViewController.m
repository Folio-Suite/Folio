// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWEditorViewController.h"
#import "../FWManuscript/FWWork.h"
#import <FolioKit/FolioKit.h>

static NSAttributedStringKey const FWEmphasis = @"FolioTextEmphasis";
static NSAttributedStringKey const FWBold = @"FolioTextBold";
static NSAttributedStringKey const FWItalic = @"FolioTextItalic";
static NSAttributedStringKey const FWUnderline = @"FolioTextUnderline";
static NSAttributedStringKey const FWStrikethrough = @"FolioTextStrikethrough";
static NSAttributedStringKey const FWParagraphIdentity = @"FolioParagraphIdentity";
static NSPasteboardType const FWTextPasteboardType = @"dev.foliosuite.text-fragment-v2";

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

static BOOL FWEmphasisUsesBold(FKTextEmphasis emphasis) {
    return emphasis == FKTextEmphasisStrongEmphasis || emphasis == FKTextEmphasisVeryStrongEmphasis;
}
static BOOL FWEmphasisUsesItalic(FKTextEmphasis emphasis) {
    return emphasis == FKTextEmphasisEmphasis || emphasis == FKTextEmphasisVeryStrongEmphasis;
}
static FKTextPresentation *FWPresentation(NSDictionary *attributes) {
    return [[FKTextPresentation alloc] initWithBold:[attributes[FWBold] boolValue] italic:[attributes[FWItalic] boolValue]
        underline:[attributes[FWUnderline] boolValue] strikethrough:[attributes[FWStrikethrough] boolValue]];
}
static void FWRenderAttributes(NSMutableDictionary *attributes) {
    FKTextEmphasis emphasis = [attributes[FWEmphasis] unsignedIntegerValue];
    NSFont *font = [NSFont fontWithName:@"Times New Roman" size:18] ?: [NSFont systemFontOfSize:18];
    NSFontTraitMask traits = 0;
    // Explicit enabled presentation traits survive semantic changes. For example,
    // Bold inside Emphasis renders bold-italic while retaining both authored values.
    if ([attributes[FWBold] boolValue] || FWEmphasisUsesBold(emphasis)) traits |= NSBoldFontMask;
    if ([attributes[FWItalic] boolValue] || FWEmphasisUsesItalic(emphasis)) traits |= NSItalicFontMask;
    attributes[NSFontAttributeName] = [NSFontManager.sharedFontManager convertFont:font toHaveTrait:traits];
    attributes[NSUnderlineStyleAttributeName] = @([attributes[FWUnderline] boolValue] ? NSUnderlineStyleSingle : 0);
    attributes[NSStrikethroughStyleAttributeName] = @([attributes[FWStrikethrough] boolValue] ? NSUnderlineStyleSingle : 0);
}
static NSDictionary *FWAttributes(FKTextEmphasis emphasis, FKTextPresentation *presentation, FKParagraphAlignment alignment) {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = FWNativeAlignment(alignment);
    style.paragraphSpacing = 10;
    NSMutableDictionary *attributes = [@{FWEmphasis:@(emphasis), FWBold:@(presentation.bold), FWItalic:@(presentation.italic),
        FWUnderline:@(presentation.underline), FWStrikethrough:@(presentation.strikethrough),
        NSForegroundColorAttributeName:NSColor.textColor, NSParagraphStyleAttributeName:style} mutableCopy];
    FWRenderAttributes(attributes);
    return attributes;
}
static BOOL FWHasFormattingConflict(NSDictionary *attributes) {
    return [attributes[FWEmphasis] unsignedIntegerValue] != FKTextEmphasisNone &&
        ([attributes[FWBold] boolValue] || [attributes[FWItalic] boolValue]);
}

@interface FWEditorViewController (InlineWarnings)
- (FKText *)unitText;
- (void)layoutFormattingMarkers;
- (void)showInlineFormattingWarning:(NSButton *)sender;
@end

@interface FWTextView : NSTextView
@property (nonatomic, weak) FWEditorViewController *editor;
@end

@implementation FWTextView
- (NSArray *)accessibilityChildren {
    // NSTextView supplies its own accessibility tree; include our inline controls.
    NSMutableArray *children = [[super accessibilityChildren] mutableCopy] ?: [NSMutableArray array];
    for (NSView *view in self.subviews) {
        for (id child in NSAccessibilityUnignoredChildren(@[view])) {
            if (![children containsObject:child]) [children addObject:child];
        }
    }
    return children;
}
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self.editor layoutFormattingMarkers];
}
- (void)toggleEmphasis:(id)sender { [self.editor toggleEmphasis:sender]; }
- (void)toggleStrongEmphasis:(id)sender { [self.editor toggleStrongEmphasis:sender]; }
- (void)toggleVeryStrongEmphasis:(id)sender { [self.editor toggleVeryStrongEmphasis:sender]; }
- (void)toggleBold:(id)sender { [self.editor toggleBold:sender]; }
- (void)toggleItalic:(id)sender { [self.editor toggleItalic:sender]; }
- (void)toggleUnderline:(id)sender { [self.editor toggleUnderline:sender]; }
- (void)toggleStrikethrough:(id)sender { [self.editor toggleStrikethrough:sender]; }
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
        [runs addObject:@{@"text":[self.string substringWithRange:range], @"emphasis":attributes[FWEmphasis] ?: @0,
                         @"bold":attributes[FWBold] ?: @NO, @"italic":attributes[FWItalic] ?: @NO,
                         @"underline":attributes[FWUnderline] ?: @NO, @"strikethrough":attributes[FWStrikethrough] ?: @NO, @"alignment":@(FWModelAlignment(style.alignment))}];
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
        for (NSString *key in @[@"emphasis", @"bold", @"italic", @"underline", @"strikethrough", @"alignment"])
            if (![run[key] isKindOfClass:NSNumber.class]) return NO;
        NSUInteger emphasis = [run[@"emphasis"] unsignedIntegerValue], alignment = [run[@"alignment"] unsignedIntegerValue];
        if (emphasis > FKTextEmphasisVeryStrongEmphasis || alignment > FKParagraphAlignmentJustified ||
            [run[@"emphasis"] doubleValue] != emphasis || [run[@"alignment"] doubleValue] != alignment) return NO;
        for (NSString *key in @[@"bold", @"italic", @"underline", @"strikethrough"])
            if (![run[key] isEqual:@NO] && ![run[key] isEqual:@YES]) return NO;
        FKTextPresentation *presentation = [[FKTextPresentation alloc] initWithBold:[run[@"bold"] boolValue]
            italic:[run[@"italic"] boolValue] underline:[run[@"underline"] boolValue] strikethrough:[run[@"strikethrough"] boolValue]];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:run[@"text"] attributes:FWAttributes(emphasis, presentation, alignment)]];
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
        NSArray<FKParagraph *> *paragraphs = self.editor.unitText.paragraphs;
        if (paragraph < paragraphs.count) [text addAttribute:FWParagraphIdentity value:paragraphs[paragraph].identifier range:NSMakeRange(0, text.length)];
    }
    [super insertText:text replacementRange:replacementRange];
}
@end

@interface FWAppearanceViewController : NSViewController
@property (nonatomic, weak) FWEditorViewController *editor;
@property (nonatomic, strong) IBOutlet NSButton *boldButton;
@property (nonatomic, strong) IBOutlet NSButton *italicButton;
@property (nonatomic, strong) IBOutlet NSButton *underlineButton;
@property (nonatomic, strong) IBOutlet NSButton *strikethroughButton;
@end

@implementation FWAppearanceViewController
- (IBAction)toggleBold:(id)sender { [self.editor toggleBold:sender]; }
- (IBAction)toggleItalic:(id)sender { [self.editor toggleItalic:sender]; }
- (IBAction)toggleUnderline:(id)sender { [self.editor toggleUnderline:sender]; }
- (IBAction)toggleStrikethrough:(id)sender { [self.editor toggleStrikethrough:sender]; }
@end

// Repeated diagnostic markers and their popover are authored in Editor.storyboard.
@interface FWFormattingWarningViewController : NSViewController
@property (nonatomic, weak) FWEditorViewController *editor;
@property (nonatomic, strong) IBOutlet NSButton *markerButton;
@end
@implementation FWFormattingWarningViewController
- (IBAction)showWarning:(NSButton *)sender { [self.editor showInlineFormattingWarning:sender]; }
- (IBAction)convertPresentationToEmphasis:(id)sender { [self.editor convertPresentationToEmphasis:sender]; }
- (IBAction)dismissFormattingWarning:(id)sender { [self.editor dismissFormattingWarning:sender]; }
@end

@interface FWEditorViewController () <NSTextViewDelegate>
@property (nonatomic, strong) IBOutlet NSTextView *textView;
@property (nonatomic, strong) NSUndoManager *editingUndoManager;
@property (nonatomic, copy) NSString *contentUnitIdentifier;
@property (nonatomic, strong) NSAttributedString *capturedText;
@property (nonatomic, strong) FKText *unitText;
@property (nonatomic, copy) NSString *trailingParagraphIdentifier;
@property (nonatomic) BOOL loading;
@property (nonatomic, strong) IBOutlet NSPopUpButton *alignmentButton;
@property (nonatomic, strong) IBOutlet NSButton *emphasisButton;
@property (nonatomic, strong) IBOutlet NSButton *strongButton;
@property (nonatomic, strong) IBOutlet NSButton *clearButton;
@property (nonatomic, strong) IBOutlet NSButton *helpButton;
@property (nonatomic, copy) NSArray<NSButton *> *formattingButtons;
@property (nonatomic, strong) NSPopover *formattingHelp;
@property (nonatomic, copy) NSArray<NSValue *> *formattingConflictRanges;
@property (nonatomic, strong) NSMutableArray<FWFormattingWarningViewController *> *formattingMarkers;
@property (nonatomic, strong) NSPopover *formattingConflictPopover;
@property (nonatomic) BOOL layingOutFormattingMarkers;
- (void)updateFormattingWarning;
@property (nonatomic, strong) NSPopover *appearancePopover;
- (IBAction)showAppearance:(id)sender;
- (IBAction)chooseEmphasis:(id)sender;
- (IBAction)chooseStrongEmphasis:(id)sender;
- (IBAction)changeParagraphAlignment:(id)sender;
- (IBAction)showFormattingHelp:(id)sender;
@end

// The storyboard owns window chrome and toolbar views; this controller routes actions.
@interface FWEditorWindowController : NSWindowController
@property (nonatomic, strong) IBOutlet NSButton *emphasisButton;
@property (nonatomic, strong) IBOutlet NSButton *strongButton;
@property (nonatomic, strong) IBOutlet NSButton *clearButton;
@property (nonatomic, strong) IBOutlet NSButton *helpButton;
@property (nonatomic, strong) IBOutlet NSPopUpButton *alignmentButton;
@end

@implementation FWEditorWindowController
- (FWEditorViewController *)formattingEditor {
    NSViewController *content = self.contentViewController;
    return [content respondsToSelector:NSSelectorFromString(@"activeEditor")] ? [content valueForKey:@"activeEditor"] : (FWEditorViewController *)content;
}
- (IBAction)showAppearance:(id)sender { [[self formattingEditor] showAppearance:sender]; }
- (IBAction)chooseEmphasis:(id)sender { [[self formattingEditor] chooseEmphasis:sender]; }
- (IBAction)chooseStrongEmphasis:(id)sender { [[self formattingEditor] chooseStrongEmphasis:sender]; }
- (IBAction)clearFormatting:(id)sender { [[self formattingEditor] clearFormatting:sender]; }
- (IBAction)changeParagraphAlignment:(id)sender { [[self formattingEditor] changeParagraphAlignment:sender]; }
- (IBAction)showFormattingHelp:(id)sender { [[self formattingEditor] showFormattingHelp:sender]; }
@end

@implementation FWEditorViewController
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager {
    return [self initWithWork:work contentUnitIdentifier:work.text.identifier undoManager:undoManager];
}
- (instancetype)initWithWork:(FWWork *)work contentUnitIdentifier:(NSString *)identifier undoManager:(NSUndoManager *)undoManager {
    NSParameterAssert([work textWithIdentifier:identifier]);
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
    self = [storyboard instantiateControllerWithIdentifier:@"Editor" creator:^id(NSCoder *coder) {
        return [[FWEditorViewController alloc] initWithCoder:coder work:work undoManager:undoManager];
    }];
    self.contentUnitIdentifier = identifier;
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder work:(FWWork *)work undoManager:(NSUndoManager *)undoManager {
    if ((self = [super initWithCoder:coder])) {
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
    if (self.isViewLoaded && !self.loading && self.unitText) {
        BOOL changed = ![self.capturedText isEqualToAttributedString:self.textView.textStorage];
        [self captureText];
        [self updateFormattingControls];
        if (changed && self.undoDidChangeText) self.undoDidChangeText();
    }
}
- (NSWindowController *)makeWindowController {
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
    FWEditorWindowController *controller = [storyboard instantiateControllerWithIdentifier:@"EditorWindow"];
    [self connectToolbar:controller];
    controller.contentViewController = self;
    (void)self.view;
    [self updateFormattingControls];
    return controller;
}
- (void)connectToolbar:(FWEditorWindowController *)controller {
    self.emphasisButton = controller.emphasisButton;
    self.strongButton = controller.strongButton;
    self.clearButton = controller.clearButton;
    self.helpButton = controller.helpButton;
    self.alignmentButton = controller.alignmentButton;
    self.formattingButtons = @[self.emphasisButton, self.strongButton];
    [self.emphasisButton setAccessibilityLabel:@"Emphasis"];
    [self.strongButton setAccessibilityLabel:@"Strong Emphasis"];
    for (NSButton *button in self.formattingButtons) [button setAccessibilityHelp:button.toolTip];
    [self.clearButton setAccessibilityLabel:@"Clear character formatting"];
    [self.helpButton setAccessibilityLabel:@"Formatting help"];
    [self.alignmentButton setAccessibilityLabel:@"Paragraph alignment"];
    [self updateFormattingControls];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    FWTextView *text = (FWTextView *)self.textView;
    text.editor = self;
    text.delegate = self;
    text.textContainer.widthTracksTextView = YES;
    text.textContainer.containerSize = NSMakeSize(text.bounds.size.width, CGFLOAT_MAX);
    text.automaticQuoteSubstitutionEnabled = NO;
    text.automaticDashSubstitutionEnabled = NO;
    [text setAccessibilityLabel:@"Manuscript text"];
    text.identifier = @"manuscriptText";
    [self displayWork];
}
- (void)viewDidAppear {
    [super viewDidAppear];
    if (!self.parentViewController && !self.appearancePopover.shown) [self.view.window makeFirstResponder:self.textView];
}
- (void)setWork:(FWWork *)work {
    _work = work;
    self.contentUnitIdentifier = work.text.identifier;
    if (self.isViewLoaded) [self displayWork];
}
- (FKText *)unitText { return [self.work textWithIdentifier:self.contentUnitIdentifier]; }
- (void)setUnitText:(FKText *)text { [self.work replaceText:text]; }
- (void)displayWork {
    self.loading = YES;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    NSArray<FKParagraph *> *paragraphs = self.unitText.paragraphs;
    for (NSUInteger index = 0; index < paragraphs.count; index++) {
        FKParagraph *p = paragraphs[index];
        NSUInteger start = text.length;
        for (FKTextRun *run in p.runs) [text appendAttributedString:[[NSAttributedString alloc] initWithString:run.string attributes:FWAttributes(run.emphasis, run.presentation, p.alignment)]];
        if (index + 1 < paragraphs.count) [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:FWAttributes(FKTextEmphasisNone, [FKTextPresentation new], p.alignment)]];
        [text addAttribute:FWParagraphIdentity value:p.identifier range:NSMakeRange(start, text.length - start)];
    }
    [self.textView.textStorage setAttributedString:text];
    self.trailingParagraphIdentifier = paragraphs.lastObject.identifier;
    NSMutableDictionary *typing = [FWAttributes(FKTextEmphasisNone, [FKTextPresentation new], paragraphs.firstObject.alignment) mutableCopy];
    typing[FWParagraphIdentity] = paragraphs.firstObject.identifier;
    self.textView.typingAttributes = typing;
    [self.textView setSelectedRange:NSMakeRange(0, 0)];
    self.capturedText = [self.textView.textStorage copy];
    self.loading = NO;
    [self updateFormattingControls];
}
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view { return self.editingUndoManager; }
- (void)textDidChange:(NSNotification *)notification {
    if (self.loading) return;
    [self captureText];
    [self updateFormattingControls];
    if (self.textDidChange) self.textDidChange();
}
- (void)captureText {
    if (!self.unitText) return;
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
            (storage.length ? self.trailingParagraphIdentifier : self.unitText.paragraphs.firstObject.identifier);
        if (!identifier || [identifiers containsObject:identifier]) identifier = [FKIdentifiedObject new].identifier;
        [identifiers addObject:identifier];
        NSMutableArray<FKTextRun *> *runs = [NSMutableArray array];
        [storage enumerateAttributesInRange:content options:0 usingBlock:^(NSDictionary *a, NSRange range, BOOL *stop) {
            FKTextRun *run = [[FKTextRun alloc] initWithString:[storage.string substringWithRange:range]
                emphasis:[a[FWEmphasis] unsignedIntegerValue] presentation:FWPresentation(a)];
            FKTextRun *previous = runs.lastObject;
            if (previous && previous.emphasis == run.emphasis && [previous.presentation isEqual:run.presentation]) {
                runs[runs.count - 1] = [[FKTextRun alloc] initWithString:[previous.string stringByAppendingString:run.string]
                    emphasis:run.emphasis presentation:run.presentation];
            } else [runs addObject:run];
        }];
        NSParagraphStyle *style = attributes[NSParagraphStyleAttributeName];
        FKParagraphAlignment alignment = style ? FWModelAlignment(style.alignment) : FKParagraphAlignmentNatural;
        [paragraphs addObject:[[FKParagraph alloc] initWithIdentifier:identifier runs:runs alignment:alignment]];
        [storage addAttribute:FWParagraphIdentity value:identifier range:whole];
        offset += whole.length;
    }
    self.trailingParagraphIdentifier = [paragraphs.lastObject identifier];
    self.unitText = [[FKText alloc] initWithIdentifier:self.unitText.identifier title:self.unitText.title paragraphs:paragraphs formattingWarningDismissed:self.unitText.formattingWarningDismissed];
    if (self.textView.selectedRange.location == storage.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        attributes[FWParagraphIdentity] = self.trailingParagraphIdentifier;
        self.textView.typingAttributes = attributes;
    }
    self.capturedText = [storage copy];
}
// Controls reflect semantic attributes independently of their rendered font.
- (NSControlStateValue)stateForKey:(NSString *)key value:(NSUInteger)expected {
    NSRange selection = self.textView.selectedRange;
    if (!selection.length) return ([self.textView.typingAttributes[key] unsignedIntegerValue] == expected) ? NSControlStateValueOn : NSControlStateValueOff;
    __block BOOL any = NO, all = YES;
    [self.textView.textStorage enumerateAttribute:key inRange:selection options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        BOOL enabled = [value unsignedIntegerValue] == expected;
        any |= enabled;
        all &= enabled;
    }];
    return all ? NSControlStateValueOn : (any ? NSControlStateValueMixed : NSControlStateValueOff);
}
- (void)updateFormattingControls {
    if (self.parentViewController && !self.view.superview) {
        [self updateFormattingWarning];
        return;
    }
    if (self.loading || !self.isViewLoaded) return;
    NSArray *keys = @[FWEmphasis, FWEmphasis];
    NSUInteger values[] = {FKTextEmphasisEmphasis, FKTextEmphasisStrongEmphasis};
    for (NSUInteger i = 0; i < self.formattingButtons.count; i++) {
        self.formattingButtons[i].state = [self stateForKey:keys[i] value:values[i]];
    }
    FWAppearanceViewController *appearance = (FWAppearanceViewController *)self.appearancePopover.contentViewController;
    if (appearance.isViewLoaded) {
        NSArray<NSButton *> *buttons = @[appearance.boldButton, appearance.italicButton, appearance.underlineButton, appearance.strikethroughButton];
        NSArray *presentationKeys = @[FWBold, FWItalic, FWUnderline, FWStrikethrough];
        for (NSUInteger i = 0; i < buttons.count; i++) buttons[i].state = [self stateForKey:presentationKeys[i] value:1];
    }
    NSUInteger index = self.textView.selectedRange.location;
    NSParagraphStyle *style = index < self.textView.string.length ? [self.textView.textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL] : self.textView.typingAttributes[NSParagraphStyleAttributeName];
    [self.alignmentButton selectItemAtIndex:style ? FWModelAlignment(style.alignment) : FKParagraphAlignmentNatural];
    [self updateFormattingWarning];
}
- (void)updateFormattingWarning {
    NSLayoutManager *layout = self.textView.layoutManager;
    NSRange whole = NSMakeRange(0, self.textView.string.length);
    [layout removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:whole];
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    if (!self.unitText.formattingWarningDismissed) {
        [self.textView.textStorage enumerateAttributesInRange:whole options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
            if (!FWHasFormattingConflict(attributes)) return;
            [layout addTemporaryAttribute:NSBackgroundColorAttributeName
                value:[NSColor.systemYellowColor colorWithAlphaComponent:0.3] forCharacterRange:range];
            NSRange previous = ranges.lastObject.rangeValue;
            if (ranges.count && NSMaxRange(previous) == range.location) {
                ranges[ranges.count - 1] = [NSValue valueWithRange:NSUnionRange(previous, range)];
            } else [ranges addObject:[NSValue valueWithRange:range]];
        }];
    }
    if (![self.formattingConflictRanges isEqual:ranges]) [self.formattingConflictPopover close];
    self.formattingConflictRanges = ranges;
    [self layoutFormattingMarkers];
}
- (void)layoutFormattingMarkers {
    if (!self.isViewLoaded || self.loading || self.layingOutFormattingMarkers) return;
    self.layingOutFormattingMarkers = YES;
    @try {
        NSLayoutManager *layout = self.textView.layoutManager;
        [layout ensureLayoutForTextContainer:self.textView.textContainer];
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
        NSMutableIndexSet *markedLines = [NSMutableIndexSet indexSet];
        NSPoint origin = self.textView.textContainerOrigin;
        for (NSValue *value in self.formattingConflictRanges) {
            NSRange range = value.rangeValue;
            if (!range.length || NSMaxRange(range) > self.textView.string.length) continue;
            NSUInteger glyph = [layout glyphIndexForCharacterAtIndex:NSMaxRange(range) - 1];
            NSRange lineRange;
            NSRect line = [layout lineFragmentUsedRectForGlyphAtIndex:glyph effectiveRange:&lineRange];
            if ([markedLines containsIndex:lineRange.location]) continue;
            [markedLines addIndex:lineRange.location];
            // Place diagnostics in the trailing inset, after the affected visual line.
            // They are real accessible controls, not characters or text attachments.
            NSRect frame = NSMakeRect(origin.x + NSMaxX(line) + 3, origin.y + NSMidY(line) - 10, 20, 20);
            frame.origin.x = MIN(frame.origin.x, NSMaxX(self.textView.bounds) - 22);
            [frames addObject:[NSValue valueWithRect:frame]];
        }
        if (!self.formattingMarkers) self.formattingMarkers = [NSMutableArray array];
        while (self.formattingMarkers.count > frames.count) {
            [self.formattingConflictPopover close];
            [self.formattingMarkers.lastObject.view removeFromSuperview];
            [self.formattingMarkers removeLastObject];
        }
        while (self.formattingMarkers.count < frames.count) {
            NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
            FWFormattingWarningViewController *marker = [storyboard instantiateControllerWithIdentifier:@"FormattingConflictMarker"];
            marker.editor = self;
            (void)marker.view;
            marker.markerButton.contentTintColor = NSColor.systemOrangeColor;
            marker.markerButton.accessibilityLabel = @"Formatting conflict";
            marker.markerButton.accessibilityHelp = @"Bold or Italic overlaps semantic emphasis. Show conversion and dismissal options.";
            marker.markerButton.identifier = @"formattingConflictMarker";
            [self.textView addSubview:marker.view];
            [self.formattingMarkers addObject:marker];
        }
        for (NSUInteger i = 0; i < frames.count; i++) self.formattingMarkers[i].view.frame = frames[i].rectValue;
    } @finally {
        self.layingOutFormattingMarkers = NO;
    }
}
- (void)showInlineFormattingWarning:(NSButton *)sender {
    if (!self.formattingConflictPopover) {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
        FWFormattingWarningViewController *content = [storyboard instantiateControllerWithIdentifier:@"FormattingConflict"];
        content.editor = self;
        self.formattingConflictPopover = [NSPopover new];
        self.formattingConflictPopover.behavior = NSPopoverBehaviorTransient;
        self.formattingConflictPopover.contentViewController = content;
    }
    [self.formattingConflictPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}
- (void)setFormattingWarningDismissed:(BOOL)dismissed {
    BOOL previous = self.unitText.formattingWarningDismissed;
    if (previous == dismissed) return;
    [self.editingUndoManager registerUndoWithTarget:self handler:^(FWEditorViewController *editor) {
        [editor setFormattingWarningDismissed:previous];
    }];
    self.unitText = [[FKText alloc] initWithIdentifier:self.unitText.identifier title:self.unitText.title paragraphs:self.unitText.paragraphs
        formattingWarningDismissed:dismissed];
    [self updateFormattingWarning];
    if (self.textDidChange) self.textDidChange();
}
- (IBAction)dismissFormattingWarning:(id)sender {
    [self.formattingConflictPopover close];
    [self setFormattingWarningDismissed:YES];
    [self.editingUndoManager setActionName:@"Dismiss Formatting Warning"];
}
- (IBAction)convertPresentationToEmphasis:(id)sender {
    [self.formattingConflictPopover close];
    void (^convert)(NSMutableDictionary *) = ^(NSMutableDictionary *attributes) {
        if (!FWHasFormattingConflict(attributes)) return;
        FKTextEmphasis emphasis = [attributes[FWEmphasis] unsignedIntegerValue];
        BOOL bold = [attributes[FWBold] boolValue] || FWEmphasisUsesBold(emphasis);
        BOOL italic = [attributes[FWItalic] boolValue] || FWEmphasisUsesItalic(emphasis);
        attributes[FWEmphasis] = @(bold && italic ? FKTextEmphasisVeryStrongEmphasis :
            (bold ? FKTextEmphasisStrongEmphasis : FKTextEmphasisEmphasis));
        attributes[FWBold] = @NO;
        attributes[FWItalic] = @NO;
        FWRenderAttributes(attributes);
    };
    [self.editingUndoManager beginUndoGrouping];
    [self editAttributesInRange:NSMakeRange(0, self.textView.string.length) name:@"Convert Presentation to Emphasis" transform:convert];
    if (!self.textView.selectedRange.length && FWHasFormattingConflict(self.textView.typingAttributes)) {
        NSDictionary *before = self.textView.typingAttributes;
        NSMutableDictionary *after = [before mutableCopy];
        convert(after);
        [self applyTypingFormatting:after];
    }
    [self setFormattingWarningDismissed:YES];
    [self.editingUndoManager setActionName:@"Convert Presentation to Emphasis"];
    [self.editingUndoManager endUndoGrouping];
    [self updateFormattingControls];
}
- (void)applyTypingFormatting:(NSDictionary *)attributes {
    NSDictionary *previous = self.textView.typingAttributes;
    [self.editingUndoManager registerUndoWithTarget:self handler:^(FWEditorViewController *editor) {
        [editor applyTypingFormatting:previous];
    }];
    self.textView.typingAttributes = attributes;
    [self updateFormattingControls];
}
- (void)textViewDidChangeSelection:(NSNotification *)notification {
    [self updateFormattingControls];
}
- (void)textViewDidChangeTypingAttributes:(NSNotification *)notification {
    [self updateFormattingControls];
}
- (void)toggleEmphasis:(id)sender { [self toggleKey:FWEmphasis value:FKTextEmphasisEmphasis name:@"Emphasis"]; }
- (void)toggleStrongEmphasis:(id)sender { [self toggleKey:FWEmphasis value:FKTextEmphasisStrongEmphasis name:@"Strong Emphasis"]; }
- (void)toggleVeryStrongEmphasis:(id)sender { [self toggleKey:FWEmphasis value:FKTextEmphasisVeryStrongEmphasis name:@"Very Strong Emphasis"]; }
- (void)toggleBold:(id)sender { [self toggleKey:FWBold value:1 name:@"Bold"]; }
- (void)toggleItalic:(id)sender { [self toggleKey:FWItalic value:1 name:@"Italic"]; }
- (void)toggleUnderline:(id)sender { [self toggleKey:FWUnderline value:1 name:@"Underline"]; }
- (void)toggleStrikethrough:(id)sender { [self toggleKey:FWStrikethrough value:1 name:@"Strikethrough"]; }
- (IBAction)showAppearance:(NSButton *)sender {
    if (self.appearancePopover.shown) { [self.appearancePopover performClose:sender]; return; }
    if (!self.appearancePopover) {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
        FWAppearanceViewController *content = [storyboard instantiateControllerWithIdentifier:@"Appearance"];
        content.editor = self;
        (void)content.view;
        self.appearancePopover = [NSPopover new];
        self.appearancePopover.behavior = NSPopoverBehaviorTransient;
        self.appearancePopover.contentViewController = content;
    }
    [self updateFormattingControls];
    [self.appearancePopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}
- (IBAction)chooseEmphasis:(NSButton *)sender {
    if (NSEvent.modifierFlags & NSEventModifierFlagOption) [self toggleItalic:sender];
    else [self toggleEmphasis:sender];
}
- (IBAction)chooseStrongEmphasis:(NSButton *)sender {
    if (NSEvent.modifierFlags & NSEventModifierFlagOption) [self toggleBold:sender];
    else [self toggleStrongEmphasis:sender];
}
- (IBAction)showFormattingHelp:(NSButton *)sender {
    if (!self.formattingHelp) {
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Editor" bundle:[NSBundle bundleWithIdentifier:@"dev.foliosuite.WriteKit"]];
        NSViewController *content = [storyboard instantiateControllerWithIdentifier:@"FormattingHelp"];
        self.formattingHelp = [NSPopover new];
        self.formattingHelp.behavior = NSPopoverBehaviorTransient;
        self.formattingHelp.contentViewController = content;
    }
    [self.formattingHelp showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}
- (void)toggleKey:(NSString *)key value:(NSUInteger)value name:(NSString *)name {
    BOOL remove = [self stateForKey:key value:value] == NSControlStateValueOn;
    void (^change)(NSMutableDictionary *) = ^(NSMutableDictionary *attributes) {
        attributes[key] = @(remove ? 0 : value);
        FWRenderAttributes(attributes);
    };
    if (!self.textView.selectedRange.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        change(attributes);
        self.textView.typingAttributes = attributes;
        [self updateFormattingControls];
        if (!self.appearancePopover.shown) [self.view.window makeFirstResponder:self.textView];
    } else [self editAttributesInRange:self.textView.selectedRange name:name transform:change];
}
- (void)clearFormatting:(id)sender {
    void (^clear)(NSMutableDictionary *) = ^(NSMutableDictionary *attributes) {
        attributes[FWEmphasis] = @(FKTextEmphasisNone);
        for (NSString *key in @[FWBold, FWItalic, FWUnderline, FWStrikethrough]) attributes[key] = @NO;
        FWRenderAttributes(attributes);
    };
    if (!self.textView.selectedRange.length) {
        NSMutableDictionary *attributes = [self.textView.typingAttributes mutableCopy];
        clear(attributes);
        self.textView.typingAttributes = attributes;
        [self updateFormattingControls];
        if (!self.appearancePopover.shown) [self.view.window makeFirstResponder:self.textView];
    } else [self editAttributesInRange:self.textView.selectedRange name:@"Clear Formatting" transform:clear];
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
    if (!self.appearancePopover.shown) [self.view.window makeFirstResponder:self.textView];
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
- (IBAction)changeParagraphAlignment:(NSPopUpButton *)sender {
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
    if (!self.appearancePopover.shown) [self.view.window makeFirstResponder:self.textView];
}
@end
