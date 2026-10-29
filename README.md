# LetterGrid

[![Tests](https://github.com/apakabarlabs/lettergrid-swift/actions/workflows/tests.yml/badge.svg)](https://github.com/apakabarlabs/lettergrid-swift/actions/workflows/tests.yml)
[![Documentation](https://github.com/apakabarlabs/lettergrid-swift/actions/workflows/documentation.yml/badge.svg)](https://apakabarlabs.github.io/lettergrid-swift/documentation/lettergrid/)

Build and play word searches in Swift, with optional SwiftUI views.

```swift
import LetterGrid

let generator = BoardGenerator(
  columns: 7, rows: 7, directions: [.right, .down],
  filler: try LetterWeights(["x": 1, "q": 1, "z": 1]))
let board = try generator.board(for: ["cat", "dog", "sun"], seed: 42)
let round = Round(board: board, directions: [.right, .down])
```

| The library | The app |
|---|---|
| placement, selection, hints, optional countdown | game rules, levels, scores, persistence, colours |

SwiftUI apps draw the round with `LetterBoard` and `HiddenWordList` from `LetterGridUI`.

## Installation

Swift 6, iOS 17+ or macOS 14+. The core also builds on Linux.

```swift
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.19.0")

.product(name: "LetterGrid", package: "lettergrid-swift"),
.product(name: "LetterGridUI", package: "lettergrid-swift") // only for SwiftUI
```

## Paths with turns

Pass the same `rules:` to the generator and the round.

```swift
let straight = WordRule(startDirections: Direction.allCases)
let bent = WordRule(startDirections: [.right], turns: 2)
let generator = BoardGenerator(
  columns: 7, rows: 7, rules: [straight, bent],
  filler: try LetterWeights(["x": 1, "q": 1]))
let request = try generator.request(for: ["planet", "star"], firstRule: bent)
let round = Round(board: request.board(seed: 42), rules: [straight, bent])
```

## Saving a game

A seed alone does not keep a layout across library updates. Save the board's letters and placements together with `round.progress`, and restore them through the checking initializers:

```swift
let placements = try saved.map { try Placement(validating: $0.word, cells: $0.cells) }
let board = try Board(validating: letters, placements: placements)
let round = try Round(
  restoring: savedProgress, board: board, directions: [.right, .down], seconds: 60)
```

## Documentation

- [LetterGrid](https://apakabarlabs.github.io/lettergrid-swift/documentation/lettergrid/): generation guarantees, height limits, filler, turns, restoring
- [LetterGridUI](https://apakabarlabs.github.io/lettergrid-swift/ui/documentation/lettergridui/): board views and highlights
- [Changelog](https://github.com/apakabarlabs/lettergrid-swift/blob/main/CHANGELOG.md): migration steps between versions

## Build and test

    make install-tools   # swiftlint, swift-format, commentcensor
    make build           # lint, tests, build
    make test            # host tests, no device
    make bench           # release performance measurements
    make docs            # both DocC references, on macOS

### Lines of Code Over Time
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history-light.svg">
  <img src="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history.svg" alt="Lines of code over time">
</picture>
