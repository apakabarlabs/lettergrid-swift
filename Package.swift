// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LetterGrid",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "LetterGrid", targets: ["LetterGrid"]),
    .library(name: "LetterGridUI", targets: ["LetterGridUI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
  ],
  targets: [
    .target(
      name: "LetterGrid", dependencies: ["Yams"], resources: [.copy("generation.yaml")]),
    .target(name: "LetterGridUI", dependencies: ["LetterGrid"]),
    .testTarget(
      name: "LetterGridTests", dependencies: ["LetterGrid", "Yams"], resources: [.copy("Fixtures")]),
    .executableTarget(
      name: "LetterGridBenchmarks", dependencies: ["LetterGrid"], path: "Benchmarks"),
  ]
)
