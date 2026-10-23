# LetterGrid

A grid of letters with words hidden in it, read across, up or down, or diagonally, either
way along each line, for iOS apps written in Swift. It builds the grid so that every
word sits there exactly once and, as long as it can, no other word of a given dictionary
turns up by chance; it follows a finger drawn along a word, opens letters as hints, and
draws the grid and the list of words to find in SwiftUI.

Everything that shapes a grid — its width, the least number of rows, which directions words
run in, how many stand upright, the letters the empty cells are filled with, the order hints
open letters in — is passed in by the app, so one app can play a timed game over a long word
list and another a short exercise over the words of a lesson.

## Installation

```swift
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.9.0")
```

`LetterGrid` holds the grid, the round and the countdown; `LetterGridUI` draws them in
SwiftUI.

Directions are opt-in: pass `.right` and `.down` for orthogonal words, `.downRight` and
`.downLeft` for diagonals down, and `.left`, `.up`, `.upLeft` and `.upRight` for words read
backwards. YAML uses `down_right`, `down_left`, `up_left` and `up_right`. The vertical-word
quota counts `.down` and `.up` placements. Selection snaps to the nearest allowed direction;
with any diagonal enabled, a gesture must be within 22.5 degrees of an allowed direction.
Orthogonal layouts with only `.right` and `.down` keep their placement algorithm.

A word that reads the same backwards, such as LEVEL, counts as one word even when both
directions of its line are enabled: it stands on the board once, and a drag from either end
finds it.

Words and filler letters go on the board in capitals, one cell per letter. A letter whose
capital is longer than one character, such as Armenian `և` (capital `ԵՒ`) or German `ß`
(`SS`), stays as it is and keeps its own cell. `cellUppercased` on `String` and `Character`
gives that form, so an app can spell a word the way the board holds it.

The filler letters come from `LetterWeights`, which maps each letter to a weight. Its
`sameNeighbour` factor, between 0 and 1, keeps equal letters apart: a letter's weight is
multiplied by it for each neighbouring cell that already holds that letter, in any of the
eight directions. With the default of 1 letters follow their weights alone.

```swift
let filler = try LetterWeights(["a": 8.2, "e": 12.7, "t": 9.1, "q": 0.1], sameNeighbour: 0.2)
```

`LetterHighlight` draws a capsule between two cell centres, so an app can show the same
path geometry over its own grid content.

`LetterBoard` accepts an optional `label: (Character) -> String` that sets the text each
cell shows, so an app can show the same board in another script. All cells share one font
size, set by the longest label. `label` runs for every cell on every redraw, so keep it a
lookup.

It also accepts an optional `missed: Placement?` for a word that should remain highlighted
after play ends. Its path uses `LetterGridStyle.rejected`, above the other paths and below
the board's single layer of letters. Omitting `missed` preserves the usual board. This
does not change the round, word placement or saved board data.

The app can apply SwiftUI's `textCase` to the board to change every displayed letter
consistently, labels and the missed word included. `.uppercase` turns a cell holding `և`
or `ß` into two letters; to show such letters in capitals, pass a `label` instead.

Building a grid takes two steps: the words are checked once, and a board is then built for
them without any way to fail.

```swift
let request = try generator.request(for: ["cat", "dog", "sun"], firstDirection: .down)
let board = generator.board(for: request, seed: 42)
```

`request(for:firstDirection:)` throws `BoardGenerator.Failure.noRoom` when no grid can hold
the words:

- a word is shorter than two letters, or two are the same after uppercasing;
- one word contains another, which would then read twice;
- both directions of a line are enabled and one word contains another read backwards;
- every filler letter is used by the words;
- the directions cannot be assigned: the first word does not fit `firstDirection` or it is
  not enabled, or the vertical quota cannot be met.

`board(for:seed:)` then always returns a board with every word exactly once. It first
searches for a clean board, one where no other dictionary word reads by chance: empty cells
get seeded, weighted letters, unwanted words are rejected as they complete, and the search
backtracks. `attempts`, `layoutsPerAttempt` and `fillsPerAttempt` bound it. If the bound is
reached, the words are laid out one per band of rows with an empty row between bands, and
the empty cells take only filler letters that none of the words use. No word can then read
anywhere but in its own place, but another dictionary word may.

Within each attempt, the sampled layouts are ranked by fewest rows, then by most shared
letters: a cell used by three words saves two cells. Equal scores keep the first sampled
layout. The search does not guarantee the most crossings among all possible layouts.
Updating from 0.8.0 can change a board rebuilt from the same seed. Reloading saved letters
and placements without regenerating the board keeps the same layout.

`board(for:seed:firstDirection:)` does both steps and throws what the request throws.

## Build and test

    make install-tools   # swiftlint, swift-format, commentcensor
    make build           # lint, tests, build
    make test            # the tests, on the host, no device

The SwiftUI part builds only where SwiftUI exists; everything else builds and is tested on
Linux as well.

### Lines of Code Over Time

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history-light.svg">
  <img src="https://raw.githubusercontent.com/apakabarlabs/lettergrid-swift/main/.github/loc-history-light.svg" alt="Lines of code over time">
</picture>
