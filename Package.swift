// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LetterGrid",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "LetterGrid", targets: ["LetterGrid"]),
    .library(name: "LetterGridUI", targets: ["LetterGridUI"]),
  ],
  targets: [
    .target(name: "LetterGrid"),
    .target(name: "LetterGridUI", dependencies: ["LetterGrid"]),
    .testTarget(name: "LetterGridTests", dependencies: ["LetterGrid"]),
  ]
)
