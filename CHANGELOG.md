# Changelog

## [0.3.0] - 2026-10-20

### Added

- `LetterBoard` can highlight one missed word over previously found words while keeping
  its letters readable. Pass one of the board's `Placement` values as `missed: placement`
  to show it and `missed: nil` to remove it;
  the caller decides when a word is missed and how long it stays highlighted. It uses
  the rejection colour supplied by the app. Existing calls need no changes.

## [0.2.2] - 2026-10-19

### Fixed

- Grid generation tries alternative filler letters instead of discarding a whole random
  grid after finding an unwanted dictionary word. This lets it find valid grids that
  previously exhausted the generation attempts. Search remains bounded and throws
  `BoardGenerator.Failure.noRoom` when it cannot produce a valid grid.
- Generation now rejects a minimum count of vertical words that cannot be met, target
  words repeated after uppercasing, and targets shorter than two letters. Call signatures
  are unchanged; callers supplying these inputs must correct them or handle `noRoom`.

## [0.2.1] - 2026-10-18

### Added

- Pass `firstDirection:` to `board(for:seed:firstDirection:)` to require the first word
  to use that direction. Word order and the requested count of vertical words are
  preserved. An impossible requirement throws `BoardGenerator.Failure.noRoom`.
  Existing calls need no changes.

## [0.2.0] - 2026-10-18

### Added

- Add `.downRight` or `.downLeft` to the allowed directions to enable downward diagonals
  in word placement, finger selection and SwiftUI highlights. Existing calls need no
  changes; generators allowing only right and down keep their placement algorithm.
- `LetterHighlight` draws a path between two cell centres over custom grid content.

## [0.1.0] - 2026-10-12

First release: a word search grid for Swift apps on iOS 17 and macOS 14 or later, added with
Swift Package Manager.

### Added

- `BoardGenerator` builds a grid of letters hiding each given word exactly once, read left to
  right or top to bottom. It checks for unwanted matches from the supplied dictionary in
  the allowed directions. A word too long for the width stands upright and the
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
