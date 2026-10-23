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
