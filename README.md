# Folio

A native macOS Suite for creating and publishing complex, technical, or large-scale Works.

Open `Folio.xcworkspace` after initializing its submodules. The workspace contains FolioKit, Write, and Research; the parent repository pins their revisions and holds shared architecture and build configuration.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checkout, build, test, namespace, and cross-repository workflows. Write has a first native text editor with Core Data Work packages; see [its implementation notes](Write/docs/native-work-v1.md). The applications remain experimental, and cross-application Work Session ownership and archival exchange remain separate work against the contracts in `docs/architecture/`.

The [current library layout](docs/architecture/current-library-layout.md) describes how the editor implementation is divided among the existing dynamic libraries and exposed through FolioKit and WriteKit.
