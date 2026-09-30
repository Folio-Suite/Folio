<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# First Write editor

Open the Suite workspace and select **Write** in Xcode. Development launch uses the workspace's shared framework products. The Suite build uses installed shared Kits; the standalone build embeds the required Kits in each application. See [build configurations](../../CONTRIBUTING.md) for selecting a distribution layout.

The editor supports paragraphs, semantic emphasis and strong emphasis, explicit bold and italic, paragraph alignment, native undo/redo, Save, Open, and Auto Save in place. The Format menu exposes the supported text operations. Ordinary copy-paste within Write retains these text properties while creating independent paragraph identities; external paste currently imports plain text.

## Ownership

`WriteDocument` is the NSDocument adapter in the application. `ManuscriptViewController` owns the storyboard-defined sidebar, selected unit, and retained unit editors. `EditorViewController` in `Core/WriteKit` owns selection, typing attributes, and the AppKit rendering of semantic text. `Work` exposes immutable text snapshots and a package read/write interface. Its private `WorkStore` implementation owns Core Data persistence. `Core/FolioKit`'s `Manuscript` holds the reading order of text Content Units. Its `TextUnit`, `TextParagraph`, and `TextRun` contain reusable Foundation-only authored text, with meaning and appearance represented separately.

For this first slice, NSDocument operates in the Write process. A separately supervised domain persistence executable is deferred; this is not the multi-application Work Session/lifetime proof. The interface keeps Core Data and package serialization out of the editor and application UI.

## Native storage

A `.flwrbundle` package has UTI `app.foliosuite.Write.Doc` and contains `Work.sqlite`, a Core Data SQLite store. XML belongs to the later complete-folio import/export path and is not this native representation.

The versioned Xcode model `Core/WriteKit/Resources/Work.xcdatamodeld` is the authoritative schema. Its current `WorkV1` version defines Work, Manuscript, ContentUnit, Paragraph, and Run entities. Open it in Xcode’s data model editor to inspect attributes, inverses, validation, and deletion rules. The Work owns its Content Units and Manuscript; the Manuscript arranges them through its ordered `contentUnits` relationship. Paragraphs and runs also use native ordered to-many relationships. Each relationship has an inverse, including the optional Manuscript placement on a Content Unit. Supported numeric ranges are expressed in the model; the persistence adapter validates identifier uniqueness across the Work. Work, Manuscript, Content Unit, and paragraphs retain independent identifiers. Paragraph alignment is authored presentation. Run emphasis is one exclusive enum value: None, Emphasis, Strong Emphasis, or Very Strong Emphasis. Bold, Italic, Underline, and Strikethrough are four independent Boolean attributes. ContentUnit also stores its display `title` and `formattingWarningDismissed`. The public Foundation model groups those booleans in immutable `TextPresentation`, separately from `TextRun.emphasis`.

The supported subset is a flat Manuscript with one or more text Content Units, each containing one or more paragraphs. Unplaced units, nested structure, and deletion are not yet exposed. This pre-alpha visual model intentionally replaces the experimental programmatic schema; no migration from that prototype is provided. Earlier packages are rejected by Core Data’s model-compatibility check. Retain versioned model resources and make future compatibility decisions explicitly. The reader rejects incompatible schemas, unsupported structure, duplicate identities, invalid relationships or style values, and unfamiliar package entries rather than dropping content on save. This is a limited reader, not the general extension-preserving model.

The native save path prepares a separate package through WriteKit's
`Work.stageSave(from:toEmptyPackageAt:)`. It clones the original closed SQLite
store where the filesystem supports copy-on-write, reconciles values and ordered
relationships by their existing identities, closes the staged store with DELETE
journaling, and verifies the resulting authored state. Unchanged rows are retained.
On a volume without cloning, it makes an independent file copy and reports that
cost. This is the accepted portability boundary: avoiding unchanged-asset copies
is a clone-capable-filesystem optimization; independent copying preserves correct
saves elsewhere. Both paths have bounded interruption/retry evidence in
[the persistence results](../evidence/work-persistence/README.md).
New Works still require an initial store. The `fileWrapper()` convenience
continues to support complete in-memory serialization.

`WriteDocument` supplies this preparation through NSDocument's advanced write
hook. AppKit retains safe replacement, Auto Save, Versions and change-count
handling. No writable SQLite handle targets the package being replaced. Failed
preparation preserves the original and leaves the in-memory edits available for
retry. This remains an in-process document implementation; it does not establish
the later shared Work Session host or durable history.

The old empty `NSPersistentDocument` prototype's SQLite UTI is not claimed by the new package type. No legacy store conversion or archival export is implemented in this slice.

## Manuscript navigation

The sidebar supports Add, Rename, Select, Move Up, and Move Down. Titles label Content Units without inserting headings into authored text. Selection is transient and reopening selects the first unit; order, titles, authored text, and warning dismissal persist. All controls and the split-view layout live in `Editor.storyboard`.

Each unit retains its own editor, selection, typing attributes, and scroll view for the document lifetime. Editors share the document undo manager. Switching units breaks typing coalescing and does not register an edit. Undoing a text change in another unit reveals that unit. Add, rename, and reorder participate in the same chronological history. The host clears undo history before replacing an entire Work. Retaining visited editors is an initial correctness tradeoff, not the eventual memory strategy for large Manuscripts.

## Verification

Use **Product → Test** on the workspace's **Write** scheme in Xcode. The tests cover SQLite package round trips, Unicode and whitespace, empty paragraphs, separate meaning and appearance, persistent identity, rejected corruption and unsupported data, editor formatting undo/redo, typing undo/redo with matching visible and saved text, retained first-paragraph identity when undo empties the document, and saving/reopening through NSDocument.

The semantic Emphasis controls lead the toolbar. The Appearance (BIU) popover offers independent Bold, Italic, Underline, and Strikethrough checkboxes with on, off, and mixed states. Strikethrough retains authored text and does not create a Proposed Revision. These appearance choices survive native saving and internal copy/paste; Clear Formatting removes them.

## Presentation and emphasis

Emphasis categories describe meaning, not a mandated font. The starter editor renders Emphasis as italic, Strong Emphasis as bold, and Very Strong Emphasis as bold-italic. Explicit enabled presentation choices remain in effect when emphasis changes: Bold applied to one word inside an Emphasis run renders that word bold-italic and splits the run at the selection boundaries. Other text retains its original presentation. Adjacent equal authored runs coalesce when capturing edits.

When Bold or Italic overlaps any semantic emphasis, the editor temporarily highlights the conflicting spans in yellow and places a clickable warning marker after the affected visual line. Conflicts ending on the same line share one marker. Clicking it opens conversion and dismissal choices in a popover; the marker follows wrapping and scrolling without inserting characters or attachments into the text. The marker and popover are authored in the Editor storyboard. Applying emphasis never silently converts or discards presentation. The conversion action applies to conflicting text throughout the current Content Unit, derives the exclusive category from the resulting bold/italic traits, clears explicit Bold/Italic there, and preserves Underline, Strikethrough, words, paragraph alignment, and identities. Bold-italic converts to Very Strong Emphasis. Conversion and warning dismissal are one undoable edit. Dismissal alone leaves text untouched. The dismissal flag belongs to the Content Unit, survives edits and save/reopen, and does not travel with copied text. Highlights are editor-only and are never stored as authored formatting.

## Planned semantic analysis

A later semantic analyzer should identify text with explicit Bold and/or Italic but no semantic emphasis and offer conversion. This is a review aid for authors who intended meaning; it must not assume that visual formatting proves intent or automatically replace deliberate presentation. The current overlap warning does not implement this analyzer. Future output and archival XML should represent the authored enum and independent booleans explicitly, without deriving semantics from the editor’s visual idiom.

## Explicit opaque-resource storage

Text-only packages remain V1, containing exactly `Work.sqlite`, with the existing
WorkV1 Core Data model. Opening and editing the supported baseline does not
upgrade it. Unknown package members continue to be rejected.

A host can explicitly call `Work.upgradeStorage()` before importing opaque
resources. This opts the pending Work into package V2; it does not rewrite the
saved original. V2 adds a versioned `Package.json` manifest and a `Resources`
directory while retaining the same authored Core Data schema. The manifest
identifies the required resource capability, listed files, byte counts and
SHA-256 digests. Unsupported capabilities, unexpected members, invalid paths and
corrupt resources are refused rather than silently omitted.

Resources are immutable retained bytes, with public descriptors and copy-out
export. They do not introduce Figure semantics, an asset browser or automatic
resource interpretation. Imports preserve their own snapshots so changing the
source file later cannot change the Work. Native URL-based reading and staged
saving avoid using an in-memory file wrapper for the entire resource collection.

V1 remains a supported compatibility mode: resource import requires explicit
upgrade. Declining upgrade leaves the original format intact; failed preparation
also preserves the original V1 package. There is no resource-import command in
the current editor. A future UI for that operation must offer the agreed
upgrade, compatibility and cancellation choices before requesting conversion.
