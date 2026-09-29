// swift-tools-version: 6.0
// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "UndoKitInterfaceProof",
    platforms: [.macOS(.v14)],
    products: [.library(name: "UndoKitInterfaceProbe", targets: ["UndoKitInterfaceProbe"])],
    targets: [
        .target(name: "UndoKitInterfaceProbe", resources: [.process("Resources")]),
        .executableTarget(name: "InterfaceConsumer", dependencies: ["UndoKitInterfaceProbe"])
    ]
)
