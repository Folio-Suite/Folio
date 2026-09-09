// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Cocoa/Cocoa.h>
@class FWWork;

@interface FWDocument : NSDocument
@property (nonatomic, strong, readonly) FWWork *work;
@end
