// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import <Cocoa/Cocoa.h>
#import <FolioKit/FolioKit.h>
#import <ResearchKit/ResearchKit.h>
#import <WriteKit/WriteKit.h>

static BOOL WriteWrapper(NSFileWrapper *wrapper, NSURL *URL, NSError **error) {
    return [wrapper writeToURL:URL options:NSFileWrapperWritingAtomic originalContentsURL:nil error:error];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: capture-migration-baseline-fixtures OUTPUT_DIRECTORY\n");
            return 2;
        }
        NSURL *root = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        NSError *error = nil;
        NSString *frameworkPath = [NSProcessInfo.processInfo.environment[@"DYLD_FRAMEWORK_PATH"] stringByAppendingPathComponent:@"WriteKit.framework"];
        NSBundle *writeKitBundle = [NSBundle bundleWithURL:[NSURL fileURLWithPath:frameworkPath]];
        if (!writeKitBundle || ![writeKitBundle loadAndReturnError:&error]) {
            fprintf(stderr, "cannot load WriteKit resources: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        if (![NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:&error]) {
            fprintf(stderr, "cannot create output directory: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        NSString *text = @"Baseline Work fixture: authored words, Unicode café / 日本語, and paragraph order.";
        FKTextPresentation *bold = [[FKTextPresentation alloc] initWithBold:YES italic:NO underline:NO strikethrough:NO];
        FKTextRun *run = [[FKTextRun alloc] initWithString:text emphasis:FKTextEmphasisStrongEmphasis presentation:bold];
        FKParagraph *paragraph = [[FKParagraph alloc] initWithIdentifier:NSUUID.UUID.UUIDString runs:@[run] alignment:FKParagraphAlignmentLeft];
        FKTextRun *secondRun = [[FKTextRun alloc] initWithString:@"Second paragraph preserves a separate paragraph boundary." emphasis:FKTextEmphasisNone presentation:[[FKTextPresentation alloc] init]];
        FKParagraph *secondParagraph = [[FKParagraph alloc] initWithIdentifier:NSUUID.UUID.UUIDString runs:@[secondRun] alignment:FKParagraphAlignmentNatural];
        FKText *unit = [[FKText alloc] initWithIdentifier:NSUUID.UUID.UUIDString title:@"Migration baseline" paragraphs:@[paragraph, secondParagraph] formattingWarningDismissed:YES];
        FWWork *work = [FWWork new];
        work.manuscript = [[FKManuscript alloc] initWithIdentifier:work.manuscriptIdentifier units:@[unit]];
        NSFileWrapper *workPackage = [work fileWrapperWithError:&error];
        NSURL *workURL = [root URLByAppendingPathComponent:@"Baseline.flwrbundle" isDirectory:YES];
        if (!workPackage || !WriteWrapper(workPackage, workURL, &error)) {
            fprintf(stderr, "cannot write Work fixture: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        NSFileWrapper *emptyResearch = [FRLibraryPackage emptyPackageWithError:&error];
        if (!emptyResearch) {
            fprintf(stderr, "cannot create Research fixture: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        NSMutableDictionary *members = [emptyResearch.fileWrappers mutableCopy];
        NSFileWrapper *assets = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{
            @"Baseline.txt": [[NSFileWrapper alloc] initRegularFileWithContents:[@"Research baseline collected file: café, 日本語\n" dataUsingEncoding:NSUTF8StringEncoding]]
        }];
        members[@"assets"] = assets;
        NSFileWrapper *researchPackage = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:members];
        NSURL *researchURL = [root URLByAppendingPathComponent:@"Baseline.flrsbundle" isDirectory:YES];
        if (![FRLibraryPackage validatePackage:researchPackage error:&error] || !WriteWrapper(researchPackage, researchURL, &error)) {
            fprintf(stderr, "cannot write Research fixture: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        return 0;
    }
}
