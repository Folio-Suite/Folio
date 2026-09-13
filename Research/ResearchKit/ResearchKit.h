// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

//
//  ResearchKit.h
//  ResearchKit
//
//  Created by Justin Croonenberghs on 9/8/26.
//

// Supported entry point for every host, including the owning application.
// Only headers listed in the Kit module map form the public interface.
// Embedded libraries and other headers are private implementation.
#import <Foundation/Foundation.h>

//! Project version number for ResearchKit.
FOUNDATION_EXPORT double ResearchKitVersionNumber;

//! Project version string for ResearchKit.
FOUNDATION_EXPORT const unsigned char ResearchKitVersionString[];

#import <ResearchKit/FRLibraryPackage.h>
