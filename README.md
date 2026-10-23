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

The library handles placement, selection, hints and an optional countdown. The app supplies
its rules, levels, scores, persistence and colours. SwiftUI apps display the round with
`LetterBoard` and `HiddenWordList` from `LetterGridUI`. Create and control rounds on the main actor.

## Installation

Requires Swift 6, iOS 17+ or macOS 14+. The core also builds on Linux.
Add the package dependency:

```swift
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.11.0")
```

Then add products to your target's dependencies:

```swift
.product(name: "LetterGrid", package: "lettergrid-swift"),
.product(name: "LetterGridUI", package: "lettergrid-swift") // Only for SwiftUI.
```

API references: [LetterGrid](https://apakabarlabs.github.io/lettergrid-swift/documentation/lettergrid/)
and [LetterGridUI](https://apakabarlabs.github.io/lettergrid-swift/ui/documentation/lettergridui/).

## Generating boards

- Directions are opt-in, including diagonals and reverse readings. `columns` is fixed;
  `rows` is a minimum. The board grows downwards to fit the words; read its height from `board.rows`.
- Every accepted target occurs exactly once along the allowed directions. Removing other
  words from an optional `BoardGenerator` dictionary (`Set<String>`, passed as `dictionary:`) is best effort:
  bounded search falls back to a board that preserves the targets but may contain other words.
- Targets need at least two letters and cannot duplicate or contain one another. The filler
  must include a letter absent from all targets. Invalid inputs throw before generation.
- Filler weights must be positive and finite. `LetterWeights.sameNeighbour` in `(0, 1]` reduces adjacent
  repetitions; its default of `1` leaves weights unchanged.
- Compare words using `cellUppercased` rather than `uppercased()`: it keeps each character
  in one cell even when its capital would expand.

## Saving and restoring

The app serializes the board's letters and placements together with `round.progress`. A seed alone does
not preserve a layout across library updates. Restore external data through checked initializers:

```swift
let board = try Board(validating: letters, placements: placements)
let round = try Round(
  restoring: savedProgress, board: board, directions: [.right, .down], seconds: 60)
```

These report invalid data without clearing it. Nonthrowing `Board(letters:placements:)` and
`Round(board:directions:)` and its variants enforce valid inputs with preconditions.

Rounds are untimed unless given `seconds`. Use `Countdown.run` to drive introduction and clock
callbacks, or let the app own timing. The library countdown does not track elapsed time during suspension.

See the API references above for round controls, countdown callbacks and view options,
or the [changelog](https://github.com/apakabarlabs/lettergrid-swift/blob/main/CHANGELOG.md) for migration steps.

## Build and test

    make install-tools   # swiftlint, swift-format, commentcensor
    make build           # lint, tests, build
    make test            # host tests, no device
    make bench           # release performance measurements
    make docs            # both DocC references, on macOS
