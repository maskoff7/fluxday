// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "FluxdayPersistence",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "FluxdayPersistence", targets: ["FluxdayPersistence"])
  ],
  dependencies: [
    .package(path: "../CashFlowCore")
  ],
  targets: [
    .target(
      name: "FluxdayPersistence",
      dependencies: ["CashFlowCore"],
      linkerSettings: [.linkedLibrary("sqlite3")]
    ),
    .testTarget(
      name: "FluxdayPersistenceTests",
      dependencies: ["FluxdayPersistence", "CashFlowCore"]
    ),
  ]
)
