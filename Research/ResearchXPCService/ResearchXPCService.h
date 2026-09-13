// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
#import "ResearchXPCServiceProtocol.h"

// Transport adapter; domain behavior belongs to ResearchKit.
@interface ResearchXPCService : NSObject <ResearchXPCServiceProtocol>
@end
