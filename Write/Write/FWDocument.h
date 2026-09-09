#import <Cocoa/Cocoa.h>
@class FWWork;

@interface FWDocument : NSDocument
@property (nonatomic, strong, readonly) FWWork *work;
@end
