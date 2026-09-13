// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

//
//  FolioKit.h
//  FolioKit
//
//  Created by Justin Croonenberghs on 9/6/26.
//

// Supported entry point for every host, including the owning application.
// Only headers listed in the Kit module map form the public interface.
// Embedded libraries and other headers are private implementation.
#import <Foundation/Foundation.h>
#import <FolioKit/FKText.h>
#import <FolioKit/FKPackageSupport.h>

//! Project version number for FolioKit.
FOUNDATION_EXPORT double FolioKitVersionNumber;

//! Project version string for FolioKit.
FOUNDATION_EXPORT const unsigned char FolioKitVersionString[];
