// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "WordSearch",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "WordGrid", targets: ["WordGrid"]),
    .library(name: "Levels", targets: ["Levels"]),
    .library(name: "Game", targets: ["Game"]),
    .executable(name: "level-table", targets: ["LevelTable"]),
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
  ],
  targets: [
    .target(name: "WordGrid"),
    .target(name: "Levels", dependencies: ["WordGrid", "Yams"]),
    .target(name: "Game", dependencies: ["Levels", "WordGrid"]),
    .executableTarget(name: "LevelTable", dependencies: ["Levels"]),
    .testTarget(name: "GameTests", dependencies: ["Game"]),
    .testTarget(name: "WordGridTests", dependencies: ["WordGrid"]),
    .testTarget(name: "LevelsTests", dependencies: ["Levels"]),
  ]
)
