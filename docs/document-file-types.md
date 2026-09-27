<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Document file types

The Suite uses four-character lowercase filename stems, one per app. Native
working documents use `<stem>bundle`; ZIP packages use the bare stem. These are
filename conventions, not legacy Finder creator/type OSType codes.

| App | Native directory package | ZIP package | ZIP media type |
| --- | --- | --- | --- |
| Write | `.flwrbundle` | `.flwr` | `application/vnd.app.foliosuite.work+zip` |
| Research | `.flrsbundle` | `.flrs` | `application/vnd.app.foliosuite.library+zip` |
| Composer | `.flcpbundle` | `.flcp` | `application/vnd.app.foliosuite.edition+zip` |

The media types are Folio declarations, not a claim of IANA registration. The
`+zip` suffix follows [RFC 6839](https://www.rfc-editor.org/rfc/rfc6839#section-3.6).
ZIP declarations conform to `com.pkware.zip-archive` and `public.content`; native
packages conform to `com.apple.package` and `public.content`. Neither ZIP type
claims the generic `.zip` extension or `application/zip` MIME tag.

## Identifiers and implementation state

| Type | UTI | Current behavior |
| --- | --- | --- |
| Folio Write Document | `app.foliosuite.Write.Doc` | Read/write |
| Folio Write Archive | `app.foliosuite.Write.Archive` | Declared, handling reserved |
| Folio Research Document | `app.foliosuite.Research.Doc` | Read/write |
| Folio Research Archive | `app.foliosuite.Research.Archive` | Declared, handling reserved |
| Folio Composer Document | `app.foliosuite.Composer.Doc` | Declared, handling reserved |
| Folio Composer Archive | `app.foliosuite.Composer.Archive` | Declared, handling reserved |

User-facing type names use the app name plus Document or Archive; short icon
labels use Document or Archive. The app metadata catalogs localize both. Work,
Source Library, and Edition remain internal domain terms.

Each exported declaration retains the appropriate badge, short label, and SF
Symbol. Supported native formats remain Editor document types. Reserved formats
use role `None` with no document class: the system can recognize them without
advertising an unsupported Open/Save implementation.

The old `.fwdoc`, `.frlibrary`, and `.fcedition` registrations are removed; no
compatibility aliases or migration are provided at this pre-alpha stage.
Composer's old flat SQLite scaffold is no longer registered. Its two new types
are reserved, so it has no advertised editable document format until bundle
persistence is implemented. This is deliberate: a flat SQLite file must not be
saved under a directory-package extension.

This is a naming and registration change. It does not implement ZIP readers,
writers, migrations, or Composer package persistence. Existing documents are not
renamed. The ZIP container schema remains to be defined; a zipped working
package does not by itself satisfy the self-contained archival folio contract
in [ADR 0005](adr/0005-native-packages-and-archival-folios.md).

## Legacy OSType tags

The exported type declarations also supply optional `com.apple.ostype` tags:

| Document | Bundle | ZIP |
| --- | --- | --- |
| Work | `FWBK` | `FWZP` |
| Library | `FRBK` | `FRZP` |
| Edition | `FCBK` | `FCZP` |

These six distinct four-byte ASCII tags supplement the UTIs, extensions, and
MIME types. They do not stamp Finder metadata onto saved files. The four-character filename stems remain separate conventions.

All three app bundles declare the shared legacy creator signature `FOL ` through
`CFBundleSignature`. The trailing ASCII space is intentional: the value is four
bytes (`46 4f 4c 20` in hexadecimal). Modern bundle identifiers remain distinct.
