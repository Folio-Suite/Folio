<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Package containers and previews

Research date: 2026-09-30. These findings informed [the first-run container intent specification, #89](https://github.com/Folio-Suite/Folio/issues/89). That specification captures the subsequent agreed direction and explicitly permits refinement during implementation. This research note does not itself change the accepted lifecycle or claim implementation. See the [earlier packaging research](zip-xml-package-conventions.md) for OCF, ODF, and OPC comparisons.

## What Pages publicly supports

Pages, Numbers, and Keynote default to saving a single file. Users can switch between that representation and a directory package through **File > Advanced > Change File Type**. Apple recommends packages for some performance and storage situations and single files for browser uploads to third-party services. Its support page does not describe the internal editing store or save algorithm. Therefore, neither a giant Core Data store nor unpacking/repacking on every save is established. [Apple Support 119883](https://support.apple.com/en-us/119883).

A bounded historical check confirms that ZIP is an actual iWork representation: `unzip -l` of LibreOffice's [Pages 5 fixture](https://github.com/LibreOffice/libetonyek/blob/37704aa6ac808fe7f7a14b4515503c3de3bc0dbf/src/test/data/pages5-file.pages) lists 14 entries: eight `Index/*.iwa` components, metadata including plists, and three JPEG previews. The fixture's SHA-256 is `b5de90dfa78077c62e1c88ddaa188e412ffa9dd31558e2774715733f9d58dfe7`. Its entry dates are from 2015; this establishes historical file contents, not current Pages internals or its live editing mechanism.

## Folio metadata and entry points

`META-INF/Info.plist` is a reasonable Folio convention. Plists support dictionary/array trees and primitive values with XML and binary representations. Use a small, versioned dictionary that identifies roots, representations, and required capabilities. Folio must define those keys and relationships; adopting plist syntax does not supply document semantics. [Apple property list guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/AboutPropertyLists/AboutPropertyLists.html).

Apple documents specific bundle layouts and `Info.plist` locations; this research found no documented automatic interpretation of `META-INF/Info.plist`. Treat it as Folio-owned discovery metadata. XML plists use Apple's fixed element vocabulary, so application vocabulary belongs in dictionary keys and version identifiers rather than custom namespaced XML elements. [Bundle structures](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html), [property list guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/AboutPropertyLists/AboutPropertyLists.html).

`Stores/$.plist` can be a literal, documented entry point, although `$` has no special plist meaning. Recommended initial roles: `Stores/` for private databases, `Objects/` for identified authored objects, `Resources/` for supporting dependencies, and `Config/` for document configuration. Keep filenames and relationships explicit rather than inferred from directory order. These are proposals, not platform rules.

## Quick Look and ZIP order

The name is **`QuickLook/`**. Apple's archived guide documents automatic bundled static images at `QuickLook/Thumbnail.ext` and `QuickLook/Preview.ext`. It does not specify ZIP entry order or compression. That older guidance should be tested on supported macOS versions, especially for a custom ZIP document type. [Quick Look guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/Quicklook_Programming_Guide/Articles/QLImplementationOverview.html).

Current APIs provide thumbnail extensions for custom types and preview extensions returning images, PDF, or HTML. A multipage PDF is a suitable proposed preview representation; automatic discovery of a PDF inside our ZIP remains unverified. [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing), [QLPreviewReply](https://developer.apple.com/documentation/quicklookui/qlpreviewreply).

OCF requires its `mimetype` entry first, uncompressed, with tightly constrained header/content rules. Folio can borrow that structure with its own media type. Placing an uncompressed thumbnail second and compressed `META-INF/Info.plist` third would be **Folio rules**, not Apple requirements. Directory packages themselves have no archive entry order. [OCF ZIP container](https://www.w3.org/TR/epub-33/#sec-zip-container).

## Native transport versus semantic archive

A ZIP of a coherent native package can be a convenient native transport representation. It does not make Core Data's private store encoding independently documented. Copying a live main database alone can also omit committed WAL transactions; establish a consistent store/package snapshot before archiving. [Core Data store guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/PersistentStoreFeatures.html), [Apple QA1809](https://developer.apple.com/library/archive/qa/qa1809/_index.html).

[ADR 0005](../adr/0005-native-packages-and-archival-folios.md) and [ADR 0013](../adr/0013-document-lifecycle-and-project-archives.md) currently require separately exported, documented semantic XML and preserve efficient native saving. Replacing that export with raw native ZIP, or producing an archive on every deliberate Save, changes those decisions. A documented XML-plist semantic schema could avoid bespoke XML tags while retaining independent reconstruction; it still needs defined identities, links, values, and history semantics. Recommend settling the container first, then explicitly choosing whether native ZIP is an additional transport form or a revised archival promise.
