// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

#import "FWEditorViewController.h"

// WriteKit-only collaboration. Hosts use makeWindowController instead.
@interface FWEditorViewController (ManuscriptToolbar)
- (void)connectToolbar:(NSWindowController *)controller;
@end
