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
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.17.0")
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
- Set `maxRows: rows` for an exact height, or a larger `maxRows` for a height range.
  Requests with a height limit retain a checked fallback within that limit. If bounded
  preparation finds no unique-target layout, `request(for:)` throws `noRoom` before play.
  A rejected request does not prove that no possible packing exists. The limit must be at
  least `rows`; it is available for both straight and turned paths, except `.v0p9` generation.
  Omitting `maxRows` preserves the existing growing-board behavior and seeded layouts.
- Every accepted target occurs exactly once along the allowed directions. Removing other
  words from an optional `BoardGenerator` dictionary (`Set<String>`, passed as `dictionary:`) is best effort:
  bounded search falls back to a board that preserves the targets but may contain other words.
- Targets need at least two letters and cannot duplicate or contain one another. The filler
  must include a letter absent from all targets. Invalid inputs throw before generation.
- Filler weights must be positive and finite. `LetterWeights.sameNeighbour` in `(0, 1]` reduces adjacent
  repetitions; its default of `1` leaves weights unchanged.
- Compare words using `cellUppercased` rather than `uppercased()`: it keeps each character
  in one cell even when its capital would expand.
- In generation `0.17`, nonletter target characters occupy ordinary path cells. Each gets at least
  one additional copy outside all target paths. `conditionalCharacters:` applies the same rule to
  caller-selected letters: filler never places them when they are absent from the targets.
  Conditional characters are excluded from ordinary weighted fill, and added without changing
  target cells or target uniqueness. A checked fallback keeps these guarantees for every seed;
  a request fails when no checked placement leaves room for the extra copies.

## Paths with turns

Use `rules:` in both the generator and round to enable paths with zero to three turns:

```swift
let straight = WordRule(startDirections: Direction.allCases)
let bent = WordRule(startDirections: [.right], turns: 2)
let generator = BoardGenerator(
  columns: 7, rows: 7, rules: [straight, bent],
  filler: try LetterWeights(["x": 1, "q": 1]))
let request = try generator.request(for: ["planet", "star"], firstRule: bent)
let board = request.board(seed: 42)
let round = Round(board: board, rules: [straight, bent])
```

- A rule specifies the first segment and an exact turn count. Each turn is 90 degrees,
  clockwise or counterclockwise; cells cannot repeat. `minimumLength` and `isValid` check rules.
- `rule.canFit(length:columns:maximumRows:)` checks whether one path fits an empty grid.
  It has no random choices or search budget; cache results for the lengths and dimensions
  you use. A nil height limit allows vertical growth. Letter content, multiword packing
  and quotas are not checked, so this does not guarantee that a board request will succeed.
- `WordRule.minimumTurns(toFit:startDirections:columns:maximumRows:)` returns the fewest
  turns (0 to 3) with which such a path fits, or `nil` when none does.
- `firstRule` must be one of the generator's rules and applies to its first word. The vertical
  quota counts words whose first segment runs up or down, including turned words.
- Requests check a bounded set of path shapes and reject words for which no checked unique
  placement fits. Accepted requests retain a fallback with unique targets. Fallback dictionary
  filtering remains best effort. Compact layouts prefer matching crossings within their height.
- A prepared turned request freezes its checked shapes. Board seeds vary their positions and
  filler. If every rule has zero turns, generation uses the existing straight generator.
- Turned generation keeps the unique-target weighted fill with the fewest distinct stray words
  found within the configured attempts. A clean fill returns immediately. Letters absent from all
  targets are used only when no ordinary fill has unique targets. Noise scoring prunes known words
  and has a deterministic work limit; an exhausted score is not treated as a clean board.
  Fully scored fills outrank incomplete scores; if every score is incomplete, the first
  unique-target ordinary fill is retained.
- Build `BoardDictionary(words)` once and pass it to `request.board(seed:dictionary:)` to reuse
  its prepared index across boards. The existing `Set<String>` argument remains supported.
- `Placement(word:cells:)` retains the ordered path. `direction` is its first segment;
  `turns` counts its bends. Save `cells`, rather than only `start` and `direction`, for turned words.
- `Board.occurrences(of:rules:)` counts ordered paths, folding the two readings of a palindrome
  into one. `strayWords(of:rules:)` scans dictionary prefixes along allowed paths.
- A round follows bends as drag samples arrive and backtracks to an earlier cell when revisited.
  Its hints and introduction follow the same ordered cells.
- `LetterHighlight(cells:cellSize:color:)` draws the full path. `LetterBoard.traceCells` draws
  an externally paced trace above highlights and below letters in the supplied selection colour.
  `PathReveal(cells:elapsed:duration:reduceMotion:)` supplies its growing prefix.

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

For seed-only data created with 0.9, use the `directions:` generator initializer with
`generationVersion: .v0p9` and exactly its original settings and words. This retains the old
fallback filler sequence. Rule-based generation accepts `.v0p12`, `.v0p13` and `.v0p17`; the former retains
the 0.12 rejection and fallback policy. Codable values are `0.9`, `0.12`, `0.13` and `0.17`.
Persist `BoardGenerationVersion.current`, whose value is `.v0p17`, rather than the text `current`.
Explicit older versions retain their original fill, including targets with separators.

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
