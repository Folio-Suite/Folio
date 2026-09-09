<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# First Write editor

Open the Suite workspace and select **Write** in Xcode. The current scheme assumes an installed development environment. Application packaging is separate work.

The editor supports paragraphs, semantic emphasis and strong emphasis, explicit bold and italic, paragraph alignment, native undo/redo, Save, Open, and Auto Save in place. The Format menu exposes the supported text operations. Ordinary copy-paste within Write retains these text properties while creating independent paragraph identities; external paste currently imports plain text.

## Ownership

`FWDocument` is the NSDocument adapter in the application. `FWEditorViewController` in WriteKit owns selection, typing attributes, and the AppKit rendering of semantic text. `FWWork` exposes immutable text snapshots and a package read/write interface. Its private `FWWorkStore` implementation owns Core Data persistence. FolioKit's `FKText`, `FKParagraph`, and `FKTextRun` contain reusable Foundation-only authored text, with meaning and appearance represented separately.

For this first slice, NSDocument operates in the Write process. A separately supervised domain persistence executable is deferred; this is not the multi-application Work Session/lifetime proof. The interface keeps Core Data and package serialization out of the editor and application UI.

## Native storage

A `.fwdoc` package has UTI `dev.foliosuite.Write.Work` and contains `Work.sqlite`, a Core Data SQLite store. XML belongs to the later complete-folio import/export path and is not this native representation.

The frozen programmatic model `FWStoreModelV1` defines Work, Manuscript, ContentUnit, Paragraph, and Run entities. The Work owns its Content Unit and Manuscript; the Manuscript references the Content Unit. Paragraph and run order use explicit positions. Work, Manuscript, Content Unit, and paragraphs retain independent identifiers. Paragraph alignment is authored presentation. Run meaning and appearance are independent bit fields.

The initial supported subset is one Content Unit placed in one Manuscript, containing one or more paragraphs. Future model changes must retain the v1 model and introduce explicit migration. The reader rejects incompatible schemas, unsupported structure, duplicate identities, invalid positions or style values, and unfamiliar package entries rather than dropping content on save. This is a limited reader, not the general extension-preserving model.

For this small slice, each save materializes a fresh Core Data snapshot in a temporary store, saves and closes the store with DELETE journal mode, verifies reconstruction, and hands a complete file wrapper to NSDocument for package replacement. There is no live SQLite handle into the package that NSDocument replaces, and no uncheckpointed WAL is omitted. Reading also uses an isolated temporary copy. Temporary stores are removed after the operation. This deliberately simple full-snapshot approach is not the eventual large-Work incremental persistence implementation.

The old empty `NSPersistentDocument` prototype's SQLite UTI is not claimed by the new package type. No legacy store conversion or archival export is implemented in this slice.

## Verification

Use **Product → Test** on the workspace's **Write** scheme in Xcode. The tests cover SQLite package round trips, Unicode and whitespace, empty paragraphs, separate meaning and appearance, persistent identity, rejected corruption and unsupported data, editor formatting undo/redo, typing undo/redo with matching visible and saved text, retained first-paragraph identity when undo empties the document, and saving/reopening through NSDocument.
