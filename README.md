# LetterGrid

A grid of letters with words hidden in it, read left to right or top to bottom, for iOS apps
written in Swift. It builds the grid so that every word sits there exactly once and no other
word of a given dictionary turns up by chance, follows a finger drawn along a word, opens
letters as hints, and draws the grid and the list of words to find in SwiftUI.

Everything that shapes a grid — its width, the least number of rows, which directions words
run in, how many stand upright, the letters the empty cells are filled with, the order hints
open letters in — is passed in by the app, so one app can play a timed game over a long word
list and another a short exercise over the words of a lesson.

## Installation

```swift
.package(url: "https://github.com/apakabarlabs/lettergrid-swift", from: "0.1.0")
```

`LetterGrid` holds the grid, the round and the countdown; `LetterGridUI` draws them in
SwiftUI.

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
