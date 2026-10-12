// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LetterGrid",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "LetterGrid", targets: ["LetterGrid"]),
    .library(name: "LetterGridUI", targets: ["LetterGridUI"]),
    .library(name: "Levels", targets: ["Levels"]),
    .library(name: "Game", targets: ["Game"]),
    .executable(name: "level-table", targets: ["LevelTable"]),
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
  ],
  targets: [
    .target(name: "LetterGrid"),
    .target(name: "LetterGridUI", dependencies: ["LetterGrid"]),
    .target(name: "Levels", dependencies: ["LetterGrid", "Yams"]),
    .target(name: "Game", dependencies: ["Levels", "LetterGrid"]),
    .executableTarget(name: "LevelTable", dependencies: ["Levels"]),
    .testTarget(name: "GameTests", dependencies: ["Game"]),
    .testTarget(name: "LetterGridTests", dependencies: ["LetterGrid"]),
    .testTarget(name: "LevelsTests", dependencies: ["Levels"]),
  ]
)
