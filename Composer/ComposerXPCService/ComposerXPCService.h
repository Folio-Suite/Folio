// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
#import "ComposerXPCServiceProtocol.h"

// Transport adapter; domain behavior belongs to ComposerKit.
@interface ComposerXPCService : NSObject <ComposerXPCServiceProtocol>
@end
