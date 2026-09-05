# Use native packages and export archival folios

Folio uses on-disk packages as its native storage form, with distinct package types for Works, libraries, Profiles, and other concepts defined as needed. An exported folio is the complete, durable archival exchange form of a Work, allowing reconstruction independently of the originating machine, libraries, and installed extensions.

## Consequences

- Save and Auto Save preserve native package state; exporting a folio is a separate operation. This supersedes the portable-checkpoint-on-Save assumption in the original #5 interview and the native package-versus-ZIP competition in #4 and #13.
- Native Works may reference external versioned resources. Changes to those resources are detected and adopted deliberately; archival export captures the exact dependency versions required for self-containment.
- Native Auto Save, Document Versions, and Time Machine integration remain requirements to investigate and prove, including versioned library objects. Internal working-store technology and individual package schemas remain open.
- The archival format must be extensively documented and specified for independent implementations, with purpose-appropriate standardized internal representations, explicit reader capabilities, and accurate fallbacks for extension content.
- A complete folio includes a dependency manifest and validation report, and must pass isolated reconstruction checks. Missing, inaccessible, or non-redistributable dependencies prevent a claim of completeness.

The approved details are in [the archival folio contract](../architecture/archival-folio-contract.md). Existing issues [#4](https://github.com/ctwelve/Folio/issues/4) and [#13](https://github.com/ctwelve/Folio/issues/13) retain the remaining lifecycle design and prototype work.
