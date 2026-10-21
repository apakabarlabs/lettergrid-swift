# Changelog

## [0.7.0] - 2026-10-22

### Added

- `LetterBoard` takes an optional `label`, which turns the letter of a cell into the text
  the cell shows. Pass it to show the board in another script without changing the board,
  for example Georgian letters spelled in Latin while a button is held:

  ```swift
  LetterBoard(
    round: round, style: style, label: { showsLatin ? latin[$0, default: String($0)] : String($0) },
    onTouch: touch, onDrag: drag, onRelease: release, onRejectionShown: clear)
  ```

  Selection, found words and hints still work on the board's own letters. All cells share
  one font size: labels of one or two letters keep the usual size, and a longer label
  shrinks every cell alike, so the board stays even. `LabelScale` gives that size as a
  share of the cell. A `textCase` set on the board applies to the labels too. Without
  `label` every cell shows its letter, as in 0.6.0. `label` runs for every cell on every
  redraw, a drag included, so keep it cheap: look letters up in a table built once rather
  than transliterating each time.

## [0.6.0] - 2026-10-22

### Added

- Words can be read backwards. `Direction` has four new cases: `.left`, `.up`, `.upLeft`
  and `.upRight` (`left`, `up`, `up_left`, `up_right` in YAML). `.up` is vertical, `.upLeft`
  and `.upRight` are diagonal, and `opposite` pairs each with its forward direction: `.right`
  with `.left`, `.down` with `.up`, `.downRight` with `.upLeft`, `.downLeft` with `.upRight`.
  Pass them in the `directions` of `BoardGenerator` and `Round` like the others. The
  generator's `downWords` range, which limits how many words stand upright, now counts words
  running up together with words running down. A round with only `.upLeft` or `.upRight`
  among its diagonals now follows a drag the way a round with `.downRight` or `.downLeft`
  already did: along the enabled direction closest in angle, and only within 22.5 degrees of
  it. Rounds that use only the 0.5.0 directions behave as before.
- When a direction and its opposite are both enabled, a word that reads the same backwards,
  such as LEVEL, stands on the board once, and dragging it from either end finds it.
- `LetterWeights(_:sameNeighbour:)` keeps equal filler letters apart. `LetterWeights` maps
  each letter, a one-letter string in either case, to its weight and is passed to `BoardGenerator` as `filler`, the letters the
  empty cells get. The cells are filled one at a time; for each cell, a letter's weight is
  multiplied by `sameNeighbour` once for each of the eight neighbouring cells already
  holding that letter, hidden word or filler. The factor must be above 0 and at most 1, so
  no letter is ever ruled out. With the default of 1 every board is the same as in 0.5.0.
  With a smaller factor the filler letters differ, and now and then where the words stand,
  so do not compare such boards with ones you stored before.

  ```swift
  let filler = try LetterWeights(["a": 8.2, "e": 12.7, "q": 0.1], sameNeighbour: 0.2)
  ```

### Changed

- `Direction` is an enum, so a `switch` over it that names every case and has no
  `default` stops compiling. Add the new cases:

  ```swift
  // 0.5.0
  switch direction {
  case .right, .down: "straight"
  case .downRight, .downLeft: "diagonal"
  }

  // 0.6.0
  switch direction {
  case .right, .down, .left, .up: "straight"
  case .downRight, .downLeft, .upLeft, .upRight: "diagonal"
  }
  ```
- When a direction and its opposite are both enabled, `request(for:firstDirection:)` also
  throws `BoardGenerator.Failure.noRoom` if one word, read backwards, lies inside another.
  With the words CATS and TAC, TAC backwards is CAT, which is inside CATS, so TAC would read
  a second time inside CATS. With only one direction of each pair enabled, nothing changes.
- `Board.occurrences(of:along:)`, which returns how many times a word reads along the given
  directions, now counts each set of cells once, so LEVEL read both ways over the same cells
  counts as one.

## [0.5.0] - 2026-10-21

### Changed

- The fallback board from 0.4.0, used when the search finds no board, is shorter. Words
  running down now start in the top row side by side, in the first, third, fifth column
  and so on, instead of each taking its own band of rows. Any grid row meets them only in
  single letters with a filler letter between, so each word still reads exactly once. The
  block is as tall as its longest word. When there are more words running down than such
  columns, the rest form another block below, after an empty row. Words running across or
  diagonally keep a band each below, as in 0.4.0: one row for a word across, as many rows
  as letters for a diagonal, with an empty row between bands.
  Two words running down and one diagonal, six letters each, on a grid seven columns wide
  take 6 + 1 + 6 = 13 rows instead of 6 + 1 + 6 + 1 + 6 = 20.
- Boards the search finds are the same as in 0.4.0. A fallback board for the same seed is
  not: if you store fallback boards or compare them in tests, expect the new layout.

## [0.4.0] - 2026-10-21

### Added

- Building a board is split in two. `BoardGenerator.request(for:firstDirection:)` checks
  the words and throws `noRoom` if no grid can hold them; `board(for: request, seed:)` then
  returns a board and never throws. Check the words once, for example when choosing them,
  and building the board later cannot fail:

  ```swift
  let request = try generator.request(for: words, firstDirection: .down)
  let board = generator.board(for: request, seed: seed)
  ```

  A request is rejected when a word is shorter than two letters, two words are the same
  after uppercasing, one word contains another, the words together use every letter of the
  generator's `filler`, or the directions cannot be assigned: `firstDirection` is not among
  the generator's `directions` or the first word does not fit it, or the number of words
  running down cannot fall within the generator's range `downWords`.

### Changed

- A board is now built for every set of words a request accepts. The generator first
  searches for a board where no other dictionary word reads by chance, as before, within
  `attempts`, `layoutsPerAttempt` and `fillsPerAttempt`. Where 0.3.0 threw `noRoom` after
  that search, it now lays the words out one per band of rows, with an empty row between
  bands, still honouring `firstDirection` and `downWords`, and fills the empty cells only
  with `filler` letters none of the words contain. Each word then reads exactly once, but
  another dictionary word may read by chance, and the board can be taller than `rows`.
  Nothing marks such a board.
- Boards the search finds are the same as in 0.3.0 for the same seed.
- The existing `board(for:seed:firstDirection:)` stays and does both steps. It throws
  `noRoom` only when the request is rejected. One word inside another threw `noRoom` in
  0.3.0 as well. Words that use every filler letter could get a board in 0.3.0 and are now
  rejected by the request: give the filler at least one letter the words do not use.

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
