// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "WriteXPCService.h"

@implementation WriteXPCService

// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
- (void)performCalculationWithNumber:(NSNumber *)firstNumber andNumber:(NSNumber *)secondNumber withReply:(void (^)(NSNumber *))reply {
    NSInteger result = firstNumber.integerValue + secondNumber.integerValue;
    reply(@(result));
}

@end
