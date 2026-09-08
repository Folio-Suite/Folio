# Specify a shared extensible semantic model in XML

Folio will define a substantial common document vocabulary on shared document-aware primitives, using one semantic superclass and composable declarative contracts. Built-in types and future extensions use the same modeling facilities, and an independently readable vocabulary specification defines their meaning and exchange representation. Semantic XML with namespaces, a DTD for verifiable core structure, and supplementary validation where needed keeps the native object model expressible outside Folio's runtime.

## Consequences

- Specializations preserve inherited meaning and guarantees; incompatible composed contracts invalidate a definition. Profiles specialize a shared Work model rather than creating separate models.
- The Work owns authored material, including unplaced Content Units; the Manuscript is its primary ordered arrangement. Authored semantic structure, authored presentation, editorial annotations, and imposed composition remain distinct.
- Stable object identities and vocabulary-qualified type identities are separate from numbering, marking, and definition versions. Each Work state resolves one definition version per vocabulary.
- Readers preserve unfamiliar content and permit only edits whose affected semantic requirements they can maintain. Complete, inspectable dependency declarations distinguish references, semantic maintenance, and presentation invalidation.
- Objective-C is the leading native representation, with Swift still possible. Incompatible structural migrations require corresponding framework version changes and should remain exceptional; exact framework divisions and identity encodings are not selected.
- The Suite initially implements its vocabulary comprehensively. Extension contracts support later integrations without requiring plug-ins to interpret the built-in model.

The approved [semantic model and Profile contract](../architecture/semantic-model-contract.md) resolves [issue #6](https://github.com/Folio-Suite/Folio/issues/6). It refines the output-independent Work in ADR 0001 and the independently reconstructible archival folio in ADR 0005; it does not select native storage internals or implement the model.
