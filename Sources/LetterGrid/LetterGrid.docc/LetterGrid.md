# ``LetterGrid``

Build and play a word search using plain Swift.

## Overview

Pass words, allowed directions, board dimensions and weighted filler letters to
``BoardGenerator``. Rows are a minimum, not a height limit. A board can grow downwards
to accommodate the words. Every accepted target occurs exactly once along the allowed
directions; dictionary filtering is best effort within the configured search limits.

``Board`` and ``Placement`` describe letters and their positions. ``Round`` owns the
selection, found words, hints and optional introduction and countdown. An application
owns scores, levels, persistence and any deadline that must survive suspension.

```swift
let generator = BoardGenerator(
  columns: 7, rows: 7, directions: [.right, .down],
  filler: try LetterWeights(["x": 1, "q": 1, "z": 1]))
let board = try generator.board(for: ["cat", "dog"], seed: 42)
```

Words use ``Swift/String/cellUppercased``: a capital that expands to multiple
characters leaves the original character in its single cell. Use this form when
comparing application words with board words. The same seed and configuration produce
the same board within one library version. Save letters and placements when a board
must retain its layout across library updates.

Prepare words once using ``BoardGenerator/request(for:firstDirection:)`` and build them
through ``BoardRequest/board(seed:dictionary:)``. The request retains its checked settings;
an optional dictionary can be supplied at build time. Empty word lists and invalid generator
configuration are rejected before a request is returned.

For external data, use ``Board/init(validating:placements:)`` and
``Round/init(restoring:board:directions:seconds:introduces:hintOrder:)``. These report invalid
data without replacing it. Nonthrowing initializers enforce the same programmer invariants
with preconditions. ``RoundProgress/validate(for:)`` can check a saved snapshot before its
owner starts a game.

Round directions must make every placement selectable. Empty boards are already complete;
a countdown restored at zero is already lost. A clock exists only when the caller supplies
`seconds`; a saved seconds value alone does not enable one.

``Countdown`` runs introduction and tick callbacks while their phases remain active.
Each callback must advance its part of the round. Cancellation ends normally, while other
sleep failures, invalid intervals and nonadvancing callbacks throw. It does not implement
a wall-clock deadline across application suspension.

### Generation and selection

- Directions are opt-in. The vertical quota counts only `.up` and `.down`; their serialized
  names are the case names, while diagonals use `down_right`, `down_left`, `up_left` and `up_right`.
- A palindrome occurs once even when both directions of its line are enabled, and can be
  selected from either end. Selection snaps to the nearest allowed direction. With diagonals
  enabled, a gesture must be within 22.5 degrees of an allowed direction.
- Requests reject empty target lists, words shorter than two letters, duplicates after
  uppercasing and words contained in other targets. When opposite directions are enabled,
  reverse containment is also rejected. The filler needs a letter absent from all targets,
  and directions must satisfy the vertical quota and any required first direction.
- Dimensions and `layoutsPerAttempt` must be positive. The vertical minimum, `attempts`
  and `fillsPerAttempt` must be nonnegative. Invalid settings throw
  ``BoardGenerator/Failure/invalidConfiguration``; incompatible words throw
  ``BoardGenerator/Failure/noRoom(words:columns:rows:)``.
- Each generation attempt samples `layoutsPerAttempt` layouts, preferring fewer rows and
  then more shared cells. Ties keep the first sample. Search is bounded by `attempts` and
  `fillsPerAttempt`; zero attempts selects the fallback directly. The fallback separates
  words into bands and fills gaps with letters absent from the targets. Target uniqueness
  remains guaranteed, but dictionary filtering and the maximum possible crossings do not.
- Filler weights must be positive and finite. `sameNeighbour` in `(0, 1]` multiplies a letter's
  weight once per equal neighbour in the eight surrounding cells, in searched and fallback
  boards. Its default is `1`; extreme weights are rescaled when needed for valid sampling.

### Restoring and pacing

- Boards require equally wide, nonempty rows and unique placements matching their cells.
  An entirely empty board is valid. Saved progress must name existing words, list found
  words once, use revealed-letter counts from zero up to one less than the word length,
  and have nonnegative remaining seconds.
- ``Countdown/run(_:secondsPerLetter:introduce:tick:)`` requires a positive representable
  interval. The introduction callback must change introduced cells or leave that phase;
  the tick callback must change remaining seconds or leave the playing phase. Otherwise,
  the operation throws ``Countdown/Failure`` instead of continuing without progress.

## Topics

### Building a board

- ``BoardGenerator``
- ``BoardRequest``
- ``LetterWeights``
- ``SeededRandom``

### Reading a board

- ``Board``
- ``Placement``
- ``Cell``
- ``Direction``

### Playing a board

- ``Round``
- ``RoundProgress``
- ``HintOrder``
- ``Countdown``
- ``LabelScale``
