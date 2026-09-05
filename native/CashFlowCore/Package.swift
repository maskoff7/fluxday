// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CashFlowCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [
    .library(name: "CashFlowCore", targets: ["CashFlowCore"])
  ],
  targets: [
    .target(name: "CashFlowCore"),
    .testTarget(
      name: "CashFlowCoreTests",
      dependencies: ["CashFlowCore"],
      resources: [.process("Fixtures")]
    ),
  ]
)
