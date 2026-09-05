import Foundation

public enum StorageLocations {
  public static let applicationSupportFolder = "app.fluxday.desktop"
  public static let nativeDatabaseFilename = "fluxday-native.sqlite3"
  public static let legacyDatabaseFilename = "fluxday.sqlite3"

  public static func applicationSupportDirectory(
    fileManager: FileManager = .default
  ) throws -> URL {
    let root = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return root.appendingPathComponent(applicationSupportFolder, isDirectory: true)
  }

  public static func nativeDatabaseURL(
    fileManager: FileManager = .default
  ) throws -> URL {
    try applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent(nativeDatabaseFilename)
  }

  public static func legacyDatabaseURL(
    fileManager: FileManager = .default
  ) throws -> URL {
    try applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent(legacyDatabaseFilename)
  }
}
