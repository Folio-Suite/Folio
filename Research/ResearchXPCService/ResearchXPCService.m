// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "ResearchXPCService.h"

@implementation ResearchXPCService

- (void)ping:(NSString *)nonce reply:(void (^)(NSString *, int))reply {
    reply(nonce, NSProcessInfo.processInfo.processIdentifier);
}

@end
