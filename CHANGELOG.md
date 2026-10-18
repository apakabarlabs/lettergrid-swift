# Changelog

## [0.2.1] - 2026-10-18

### Added

- An optional required direction for the first word of a generated board, preserving
  word order and the vertical-word quota. An impossible first-direction requirement
  fails explicitly.

## [0.2.0] - 2026-10-18

### Added

- Opt-in downward diagonals in both directions for placement, selection and SwiftUI
  highlights. Orthogonal-only generators retain their existing layout algorithm.
- `LetterHighlight` draws a path between two cell centres over custom grid content.

## [0.1.0] - 2026-10-12

First release: a word search grid for Swift apps on iOS 17 and macOS 14 or later, added with
Swift Package Manager.

### Added

- `BoardGenerator` builds a grid of letters hiding each given word exactly once, read left to
  right or top to bottom. Words from a dictionary you pass, such as the rest of a lesson,
  never read in the grid by chance. A word too long for the width stands upright and the
  grid grows downwards.
- `Round` plays one grid: dragging a finger along a hidden word finds it, a drag over no word
  is marked as rejected, and each hint opens one more letter of the first word not yet found.
  `HintOrder` sets which letters hints open: from the start of the word, or any but its
  first. A round can show its first word letter by letter before play, and can have a clock
  that loses the round when it runs out.
- `Countdown` paces a round in time: the letter-by-letter showing of the first word and the
  clock.
- `LetterBoard` and `HiddenWordList` draw a round in SwiftUI and update as it is played, in
  the colours of a `LetterGridStyle`.
