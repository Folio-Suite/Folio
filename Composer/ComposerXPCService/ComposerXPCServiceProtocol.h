// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

// Transport diagnostics only; domain operations belong to the owning Kit.
@protocol ComposerXPCServiceProtocol
/// Echoes a caller nonce and returns the service PID to verify a live XPC exchange.
- (void)ping:(NSString *)nonce reply:(void (^)(NSString *echo, int processIdentifier))reply;
@end
