<!--
SPDX-FileCopyrightText: 2026 Antoine van der Lee
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Models and migrations

## Find the authoritative model

Follow the repository's [data-modeling guidance](../../../../CONTRIBUTING.md#data-modeling) to the versioned `.xcdatamodeld` and load its compiled model from the owning Kit bundle. Match entity class names, modules, code generation, current model version, and build-resource membership to the implementation. A host's main bundle is not automatically the resource owner.

For a unique-entity-description error, inspect model loading, duplicate class/entity mappings, and the models used by the test stack before introducing a global model singleton. Each supported model version and store configuration still needs the correct model.

## Change schema deliberately

State whether a change affects the stored format and which existing stores must remain readable under the current repository policy. Make persistent schema changes in Xcode's model editor. Review inverses, ordered relationships, deletion rules, optionality, defaults, validation, and uniqueness constraints together with their domain meaning.

Distinguish independent uniqueness constraints from a compound constraint: one group containing multiple properties makes their combination unique. Choose merge behavior using [contexts and saving](contexts-and-saving.md#conflict-policy-follows-the-domain). For transformables, preserve the encoded format and review secure coding, allowed classes, and transformer registration before stores load.

Primary reference: [Creating a Core Data model](https://developer.apple.com/documentation/coredata/creating-a-core-data-model).

## Diagnose compatibility before migrating

Record the source store metadata, selected model/configuration, and destination model. An incompatible-version error can come from loading the wrong resource or store, not only from an intentional schema change. Work on a copy of the affected package when experimenting; store deletion is not a migration strategy for data whose preservation is required.

For supported source versions, retain their models and determine whether Core Data can infer a mapping. Use renaming identifiers to preserve property/entity identity; maintain that identity across a chain of renames rather than assuming the immediately previous spelling is always correct. If inference cannot express the required transformation, design an explicit migration appropriate to the selected SDK and deployment target.

Exercise the migration with representative old stores. Check content, relationships, ordering, identities, and additional package members after migration and again after reopening. A successful model compile or inferred mapping alone does not establish preservation. Keep downgrade expectations explicit where the product supports them.

Primary reference: [Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically).

## Use a matching test store

An in-memory store is useful for isolated object-graph behavior. Use temporary SQLite stores for SQLite-specific queries, uniqueness/merge behavior, batch requests, and migration/reopen claims. Use the same compiled model and relevant store options as the affected adapter. Await completion of all intended store loads before exercising the context, and close the stack before reopening the store for verification.

Test through the owning Kit's public behavior where possible, using private adapter tests for persistence details that the public interface deliberately hides. Follow [Folio's native validation guidance](../../../../CONTRIBUTING.md#validation) for document/package integration.
