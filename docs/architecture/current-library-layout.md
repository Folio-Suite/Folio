# Current library layout

The existing parent workspace and FolioKit, Write, and Research Git submodules remain in place. This reorganization gives the Objective-C editor's existing implementation to the dynamic library targets already in the skeleton. It is the first part of [the native shell specification](https://github.com/Folio-Suite/Folio/issues/14), not completion of that larger milestone.

| Public framework | Internal dynamic library | Current implementation |
| --- | --- | --- |
| FolioKit | FKModelFoundations | Stable identity and immutable text, paragraph, and run objects |
| FolioKit | FKPackageSupport | Temporary package staging and cleanup |
| FolioKit | FKXMLSupport | Reserved for XML exchange; no native storage responsibility |
| WriteKit | FWManuscript | Work model and private Core Data package adapter |
| WriteKit | FWEditor | AppKit editing, formatting, selection, paste, and undo adaptation |
| ResearchKit | No additional implementation libraries yet | Source Library package support for the Research shell |

Each header lives next to its implementation. Xcode publishes the selected public headers through the owning framework; the source declaration is not duplicated or replaced with a forwarding header. FolioKit and WriteKit remain the public Clang modules, with explicit module builds enabled in the shared configuration. Internal libraries do not import their own containing framework.

The frameworks re-export the dynamic libraries that implement their public classes. Libraries retain relocatable `@rpath` install names, and the framework's existing Embed Libraries phase places its libraries in its own Frameworks directory. FWEditor links FWManuscript for its model dependency; both consume shared foundations through FolioKit. Private Core Data declarations are not published as framework headers. No implementation is compiled a second time into its containing framework.

Write's application still owns NSDocument and its windows. Research also uses NSDocument for package handling, with its empty catalog store and package validation in ResearchKit. Application and document identifiers now use `dev.foliosuite`; both native formats are directory packages. Supported formatting and the current development packaging arrangement are unchanged. A separately named persistence library, Swift-backed operations, and the broader shell acceptance requirements remain subsequent work under #14.

Validate with the shared Write scheme's Test action in Xcode, which exercises public framework interfaces and the native application. Build the Folio scheme to check both domains together. The staging tests cover returned content, error propagation, independent nested directories, and cleanup after success, failure, or exception. The existing editor/document tests cover the behavior retained through this reorganization.
