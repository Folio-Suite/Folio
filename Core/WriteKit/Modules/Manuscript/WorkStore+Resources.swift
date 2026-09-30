// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CryptoKit
import FolioKit
import Foundation

private struct WorkPackageManifest: Codable {
  struct Entry: Codable {
    let identifier: String
    let filename: String
    let byteCount: Int64
    let sha256: String
  }

  let formatVersion: Int
  let requiredCapabilities: [String]
  let resources: [Entry]
}

/// Opaque resources are private snapshots, independent of their import source and document URL.
final class WorkResourceStore {
  private let directory: URL
  private var entries: [FolioIdentifier: WorkResource] = [:]

  init() {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
  }

  deinit { try? FileManager.default.removeItem(at: directory) }

  var resources: [WorkResource] {
    entries.values.sorted { $0.identifier.rawValue < $1.identifier.rawValue }
  }

  private func privateURL(_ identifier: FolioIdentifier) -> URL {
    directory.appendingPathComponent(identifier.rawValue)
  }

  private func prepareDirectory() throws {
    guard !FileManager.default.fileExists(atPath: directory.path) else { return }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  }

  func importResource(from sourceURL: URL) throws -> FolioIdentifier {
    try Self.checkRegularFile(sourceURL)
    let filename = sourceURL.lastPathComponent
    guard Self.validFilename(filename), entries.count < 4_096 else {
      throw WorkStore.resourceError()
    }
    let identifier = FolioIdentifier.make()
    guard entries[identifier] == nil else { throw WorkStore.resourceError() }
    let destination = privateURL(identifier)
    try prepareDirectory()
    _ = try WorkStore.cloneOrCopy(sourceURL, to: destination)
    do {
      let digest = try Self.digest(destination)
      entries[identifier] = WorkResource(
        identifier: identifier, filename: filename,
        byteCount: digest.bytes, sha256: digest.sha256)
      return identifier
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
  }

  func addExisting(_ resource: WorkResource, from sourceURL: URL) throws {
    guard entries[resource.identifier] == nil else { throw WorkStore.resourceError() }
    try Self.checkRegularFile(sourceURL)
    let destination = privateURL(resource.identifier)
    try prepareDirectory()
    _ = try WorkStore.cloneOrCopy(sourceURL, to: destination)
    do {
      let digest = try Self.digest(destination)
      guard digest.bytes == resource.byteCount, digest.sha256 == resource.sha256 else {
        throw WorkStore.resourceError()
      }
      entries[resource.identifier] = resource
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
  }

  func exportResource(_ identifier: FolioIdentifier, to destinationURL: URL) throws {
    guard entries[identifier] != nil, !FileManager.default.fileExists(atPath: destinationURL.path)
    else {
      throw WorkStore.missingResourceError()
    }
    try FileManager.default.copyItem(at: privateURL(identifier), to: destinationURL)
  }

  func removeResource(_ identifier: FolioIdentifier) throws {
    guard entries[identifier] != nil else { throw WorkStore.missingResourceError() }
    try FileManager.default.removeItem(at: privateURL(identifier))
    entries.removeValue(forKey: identifier)
  }

  func write(to packageURL: URL) throws -> (cloned: Int64, copied: Int64) {
    let resourceDirectory = packageURL.appendingPathComponent("Resources", isDirectory: true)
    try FileManager.default.createDirectory(
      at: resourceDirectory, withIntermediateDirectories: false)
    var cloned: Int64 = 0
    var copied: Int64 = 0
    for resource in resources {
      let destination = resourceDirectory.appendingPathComponent(resource.identifier.rawValue)
      let result = try WorkStore.cloneOrCopy(privateURL(resource.identifier), to: destination)
      let digest = try Self.digest(destination)
      guard digest.bytes == resource.byteCount, digest.sha256 == resource.sha256 else {
        throw WorkStore.resourceError()
      }
      cloned += result.cloned
      copied += result.copied
    }
    let manifest = WorkPackageManifest(
      formatVersion: 2, requiredCapabilities: ["opaque-resources-v1"],
      resources: resources.map {
        WorkPackageManifest.Entry(
          identifier: $0.identifier.rawValue,
          filename: $0.filename, byteCount: $0.byteCount, sha256: $0.sha256)
      })
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(manifest).write(
      to: packageURL.appendingPathComponent("Package.json"), options: .atomic)
    return (cloned, copied)
  }

  static func markHistory(in packageURL: URL) throws {
    let url = packageURL.appendingPathComponent("Package.json")
    let previous = try decodeManifest(Data(contentsOf: url))
    let manifest = WorkPackageManifest(
      formatVersion: 2,
      requiredCapabilities: ["opaque-resources-v1", "durable-history-v1"],
      resources: previous.resources)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(manifest).write(to: url, options: .atomic)
  }

  static func read(from packageURL: URL) throws -> WorkResourceStore {
    let manifestURL = packageURL.appendingPathComponent("Package.json")
    try checkRegularFile(manifestURL)
    let attributes = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
    guard let size = attributes[.size] as? NSNumber, size.intValue <= 4_194_304 else {
      throw WorkStore.resourceError()
    }
    let manifest = try decodeManifest(Data(contentsOf: manifestURL))
    guard manifest.formatVersion == 2,
      manifest.requiredCapabilities == ["opaque-resources-v1"]
        || manifest.requiredCapabilities == ["opaque-resources-v1", "durable-history-v1"],
      manifest.resources.count <= 4_096
    else { throw WorkStore.resourceError() }
    let historyExpected = manifest.requiredCapabilities.contains("durable-history-v1")
    guard
      historyExpected
        == FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("History").path)
    else {
      throw WorkStore.resourceError()
    }
    let resourceDirectory = packageURL.appendingPathComponent("Resources", isDirectory: true)
    let directoryValues = try resourceDirectory.resourceValues(forKeys: [
      .isDirectoryKey, .isSymbolicLinkKey,
    ])
    guard directoryValues.isDirectory == true, directoryValues.isSymbolicLink != true else {
      throw WorkStore.resourceError()
    }
    let names = try FileManager.default.contentsOfDirectory(atPath: resourceDirectory.path)
    let expected = Set(manifest.resources.map(\.identifier))
    guard names.count == manifest.resources.count, Set(names) == expected,
      manifest.resources.map(\.identifier) == manifest.resources.map(\.identifier).sorted()
    else {
      throw WorkStore.resourceError()
    }
    let store = WorkResourceStore()
    for entry in manifest.resources {
      guard validIdentifier(entry.identifier), validFilename(entry.filename), entry.byteCount >= 0,
        entry.sha256.count == 64, entry.sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase })
      else {
        throw WorkStore.resourceError()
      }
      let identifier = try FolioIdentifier(rawValue: entry.identifier)
      let resource = WorkResource(
        identifier: identifier, filename: entry.filename,
        byteCount: entry.byteCount, sha256: entry.sha256)
      try store.addExisting(
        resource, from: resourceDirectory.appendingPathComponent(entry.identifier))
    }
    return store
  }

  static func checkRegularFile(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw WorkStore.resourceError()
    }
  }

  private static func decodeManifest(_ data: Data) throws -> WorkPackageManifest {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      Set(object.keys) == ["formatVersion", "requiredCapabilities", "resources"],
      let records = object["resources"] as? [[String: Any]],
      records.allSatisfy({ Set($0.keys) == ["identifier", "filename", "byteCount", "sha256"] })
    else {
      throw WorkStore.resourceError()
    }
    return try JSONDecoder().decode(WorkPackageManifest.self, from: data)
  }

  private static func validIdentifier(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 128
      && value.utf8.allSatisfy {
        ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45
          || $0 == 95
      }
  }

  private static func validFilename(_ value: String) -> Bool {
    !value.isEmpty && value != "." && value != ".." && value.utf8.count <= 255
      && !value.contains("/") && !value.contains("\\") && !value.contains("\0")
  }

  private static func digest(_ url: URL) throws -> (bytes: Int64, sha256: String) {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    var bytes: Int64 = 0
    while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
      hasher.update(data: chunk)
      bytes += Int64(chunk.count)
    }
    let hex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    return (bytes, hex)
  }
}

extension WorkStore {
  static func resourceError() -> NSError {
    NSError(
      domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError,
      userInfo: [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "work-resource.invalid.error", tableName: nil, bundle: bundle,
          value:
            "The Work contains an invalid or unsupported resource. No content has been changed.",
          comment: "Error when a native Work resource or resource manifest cannot be validated."),
      ])
  }

  static func missingResourceError() -> NSError {
    NSError(
      domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
      userInfo: [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "work-resource.missing.error", tableName: nil, bundle: bundle,
          value: "The Work resource is unavailable.",
          comment: "Error when exporting or removing a resource identifier absent from this Work."),
      ])
  }

  static func openPackage(at packageURL: URL) throws -> (
    snapshot: Snapshot, resources: WorkResourceStore
  ) {
    let values = try packageURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else { throw resourceError() }
    let names = Set(try FileManager.default.contentsOfDirectory(atPath: packageURL.path))
    guard names == ["Work.sqlite", "Package.json", "Resources"]
      || names == ["Work.sqlite", "Package.json", "Resources", "History"]
    else {
      throw resourceError()
    }
    let resources = try WorkResourceStore.read(from: packageURL)
    let storeURL = packageURL.appendingPathComponent("Work.sqlite")
    try WorkResourceStore.checkRegularFile(storeURL)
    return (try readStore(at: storeURL), resources)
  }
}
