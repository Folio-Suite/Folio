// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "ComposerXPCService.h"

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation ServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)connection {
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ComposerXPCServiceProtocol)];
    connection.exportedObject = [ComposerXPCService new];
    [connection resume];
    return YES;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        ServiceDelegate *delegate = [ServiceDelegate new];
        NSXPCListener *listener = [NSXPCListener serviceListener];
        listener.delegate = delegate;
        [listener resume];
    }
    return 0;
}
