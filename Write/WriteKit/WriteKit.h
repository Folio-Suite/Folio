// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

//
//  WriteKit.h
//  WriteKit
//
//  Created by Justin Croonenberghs on 9/8/26.
//

// Supported entry point for every host, including the owning application.
// Only headers listed in the Kit module map form the public interface.
// Internal modules and their unpublished headers are private implementation.
#import <Foundation/Foundation.h>
#import <WriteKit/FWWork.h>
#import <WriteKit/FWEditorViewController.h>
#import <WriteKit/FWManuscriptViewController.h>

//! Project version number for WriteKit.
FOUNDATION_EXPORT double WriteKitVersionNumber;

//! Project version string for WriteKit.
FOUNDATION_EXPORT const unsigned char WriteKitVersionString[];
