import Foundation

public enum PersistenceError: Error, Equatable, Sendable {
  case sqlite(code: Int32, message: String)
  case unsupportedDatabaseVersion(Int32)
  case unsupportedSnapshotVersion(Int32)
  case invalidDocument
  case destinationNotEmpty
  case dataTooLarge
}
