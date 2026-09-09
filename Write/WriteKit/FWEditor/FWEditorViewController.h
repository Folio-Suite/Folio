#import <AppKit/AppKit.h>
@class FWWork;

NS_ASSUME_NONNULL_BEGIN

/// Native editing surface; owns selection and presentation, not file persistence.
@interface FWEditorViewController : NSViewController
@property (nonatomic, strong) FWWork *work;
@property (nonatomic, strong, readonly) NSTextView *textView;
@property (nonatomic, copy, nullable) void (^textDidChange)(void);
- (instancetype)initWithWork:(FWWork *)work undoManager:(NSUndoManager *)undoManager;
- (void)toggleEmphasis:(nullable id)sender;
- (void)toggleStrongEmphasis:(nullable id)sender;
- (void)toggleBold:(nullable id)sender;
- (void)toggleItalic:(nullable id)sender;
- (void)clearFormatting:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END
