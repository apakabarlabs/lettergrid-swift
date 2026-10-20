# LetterGrid

A grid of letters with words hidden in it, read left to right, top to bottom, or diagonally
down in either direction, for iOS apps written in Swift. It builds the grid so that every
word sits there exactly once and no other
word of a given dictionary turns up by chance, follows a finger drawn along a word, opens
letters as hints, and draws the grid and the list of words to find in SwiftUI.

Everything that shapes a grid — its width, the least number of rows, which directions words
run in, how many stand upright, the letters the empty cells are filled with, the order hints
open letters in — is passed in by the app, so one app can play a timed game over a long word
list and another a short exercise over the words of a lesson.

## Installation

```swift
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.3.0")
```

`LetterGrid` holds the grid, the round and the countdown; `LetterGridUI` draws them in
SwiftUI.

Directions are opt-in: pass `.right` and `.down` for orthogonal words, and add `.downRight`
and `.downLeft` for diagonals. YAML uses `down_right` and `down_left`. The vertical-word
quota counts `.down` placements only. Selection snaps to the nearest allowed direction;
backward and upward paths remain unavailable. With diagonals enabled, a gesture must be
within 22.5 degrees of an allowed direction. Existing orthogonal layouts keep their
placement algorithm. `LetterHighlight` draws a capsule between two cell centres, so an
app can show the same path geometry over its own grid content.

`LetterBoard` accepts an optional `missed: Placement?` for a word that should remain
highlighted after play ends. Its path uses `LetterGridStyle.rejected`, above the other
paths and below the board's single layer of letters. The app can apply SwiftUI's
`textCase` to the board to change every displayed letter consistently, including the
missed word. Omitting `missed` preserves the usual board. This does not change the round,
word placement or saved board data.

`board(for:seed:firstDirection:)` can require a direction for the first word, for example
when introducing a new path. The direction must be enabled, the first word must fit it,
and enough other words must remain to satisfy the vertical quota. Otherwise generation
throws `BoardGenerator.Failure.noRoom`.

Targets must have at least two letters and be distinct after uppercasing; invalid targets
throw `noRoom`. An impossible minimum vertical quota also throws rather than reducing it.

Empty cells are filled with seeded, weighted letter choices, rejecting unwanted words as
they become complete and backtracking when necessary. Fixed placement conflicts reject
the layout before filling. Each fill searches at most the number of empty cells times the
number of distinct filler letters; `fillsPerAttempt` bounds repeated fills, and `attempts`
bounds layouts. Exhausting this search throws `noRoom`; it does not prove that every
possible layout is impossible. Every returned board is checked again for unique targets
and stray dictionary words.

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
