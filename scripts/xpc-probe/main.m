// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
#import "WriteXPCServiceProtocol.h"
#import "ResearchXPCServiceProtocol.h"
#import "ComposerXPCServiceProtocol.h"

static void Emit(NSDictionary *record) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys error:NULL];
    puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
    fflush(stdout);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Keep successful connections alive for an external vmmap inspection.
        NSInteger hold = argc == 2 ? [[NSString stringWithUTF8String:argv[1]] integerValue] : 60;
        if (argc > 2 || hold < 0 || hold > 300) {
            fprintf(stderr, "Usage: FolioXPCProbe [hold-seconds: 0..300]\n");
            return 2;
        }
        NSArray<NSString *> *names = @[@"Write", @"Research", @"Composer"];
        NSArray *protocols = @[@protocol(WriteXPCServiceProtocol), @protocol(ResearchXPCServiceProtocol), @protocol(ComposerXPCServiceProtocol)];
        NSMutableArray<NSXPCConnection *> *connections = [NSMutableArray array];
        NSMutableSet<NSString *> *replied = [NSMutableSet set];
        __block BOOL failed = NO;
        for (NSUInteger index = 0; index < names.count; index++) {
            NSString *name = names[index];
            NSString *nonce = NSUUID.UUID.UUIDString;
            NSString *identifier = [NSString stringWithFormat:@"dev.foliosuite.%@XPCService", name];
            NSXPCConnection *connection = [[NSXPCConnection alloc] initWithServiceName:identifier];
            connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:protocols[index]];
            [connections addObject:connection];
            connection.interruptionHandler = ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    failed = YES;
                    Emit(@{@"service": identifier, @"error": @"Connection interrupted"});
                });
            };
            [connection resume];
            id proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failed = YES;
                    Emit(@{@"service": identifier, @"error": error.localizedDescription});
                });
            }];
            // All three service protocols deliberately use the same diagnostic selector.
            [proxy ping:nonce reply:^(NSString *echo, int pid) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL valid = [echo isEqualToString:nonce] && pid > 0 && pid != NSProcessInfo.processInfo.processIdentifier;
                    if (!valid) failed = YES;
                    else [replied addObject:identifier];
                    Emit(@{@"service": identifier, @"pid": @(pid), @"nonceMatched": @([echo isEqualToString:nonce]), @"passed": @(valid)});
                });
            }];
        }
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:15];
        while (!failed && replied.count < names.count && deadline.timeIntervalSinceNow > 0) {
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        BOOL passed = !failed && replied.count == names.count;
        Emit(@{@"phase": @"exchange", @"passed": @(passed), @"replyCount": @(replied.count)});
        if (passed) {
            NSDate *end = [NSDate dateWithTimeIntervalSinceNow:hold];
            while (!failed && end.timeIntervalSinceNow > 0) {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            }
        }
        for (NSXPCConnection *connection in connections) [connection invalidate];
        return passed && !failed ? 0 : 1;
    }
}
