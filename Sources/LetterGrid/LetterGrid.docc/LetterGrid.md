# ``LetterGrid``

Build and play a word search using plain Swift.

## Overview

Pass words, allowed directions, board dimensions and weighted filler letters to
``BoardGenerator``. Rows are a minimum. A board can grow downwards to accommodate the words
unless `maxRows` limits its height. Every accepted target occurs exactly once along the allowed
directions; dictionary filtering is best effort within the configured search limits.

``Board`` and ``Placement`` describe letters and their positions. ``Round`` owns the
selection, found words, hints and optional introduction and countdown. An application
owns scores, levels, persistence and any deadline that must survive suspension. Create and
control rounds on the main actor.

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

Prepare words once using ``BoardGenerator/request(for:firstDirection:firstRule:)`` and build them
through ``BoardRequest`` using `board(seed:dictionary:)`. The request retains its checked settings;
an optional dictionary can be supplied at build time. Empty word lists and invalid generator
configuration are rejected before a request is returned.

For external data, use ``Placement/init(validating:cells:)``,
``Board/init(validating:placements:)`` and
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

- Generation forbids added runs of three equal letters along any straight direction.
  Runs contained in one target word remain, but filler cannot extend them. Filling first
  tries to avoid equal neighbours, then permits pairs when that search fails. Requests
  retain a checked fallback and throw `unsettled` if bounded preparation cannot find one.
- Directions are opt-in. The vertical quota counts only `.up` and `.down`, including turned
  words whose first segment runs up or down; their serialized
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
- An optional `maxRows` must be at least `rows`. Set both to the same value for an exact
  height. Bounded requests prepare a checked fallback within that height before returning;
  failure to find one within the preparation budget throws `noRoom`, even if a different
  packing might exist. Zero attempts or fills still require fallback preparation. With `rules:`,
  generation instead searches every allowed path for any number of words: `noRoom` then
  means that no layout exists, and ``BoardGenerator/Failure/unsettled(words:columns:rows:)``
  that the search ran out first. `unsettled` also reports words that do fit, but only in
  layouts where the targets themselves put three equal letters in a line, and words whose
  layout no filler can complete without such a line. ``BoardGenerator/accepts(_:firstRule:)`` checks the word
  conditions without a board; a set it rejects always throws, and a set it accepts may still
  have no layout. Read the resulting height from `board.rows`.
  Both straight and turned paths support the limit; without it the board grows downwards.
- Each generation attempt samples `layoutsPerAttempt` layouts, preferring fewer rows and
  then more shared cells. Ties keep the first sample. Search is bounded by `attempts` and
  `fillsPerAttempt`; zero attempts selects the fallback directly. The unbounded fallback separates
  words into bands and fills gaps with letters absent from the targets. Target uniqueness
  remains guaranteed, but dictionary filtering and the maximum possible crossings do not.
- Filler weights must be positive and finite. `sameNeighbour` in `(0, 1]` multiplies a letter's
  weight once per equal neighbour in the eight surrounding cells, in searched and fallback
  boards. Its default is `1`; extreme weights are rescaled when needed for valid sampling.

### Restoring and pacing

Generation retains nonletter characters as ordinary target-path cells and adds at least
one copy of each outside all target paths. `conditionalCharacters` applies the same rule to
caller-selected letters. Ordinary weighted fill excludes these characters, so an absent
conditional character never appears on the board. Checked fallbacks retain target uniqueness
and the extra copies; requests reject layouts that cannot provide them within the search budget.

- ``WordRule`` enables zero to three exact 90-degree turns in either direction, without
  revisiting cells. Its directions apply to the first segment. Supply rules to both the
  generator and round. `firstRule` requires the first word to use one particular enabled rule.
  Words may cross only on equal letters. `minimumLength` and `isValid` check a rule.
- ``WordRule/canFit(length:columns:maximumRows:)`` checks whether one path fits an empty grid,
  with no random choices or search budget, so its results can be cached per length and size.
  A nil height limit allows vertical growth. It ignores letters, multiword packing and quotas,
  so it does not promise that a board request succeeds.
  ``WordRule/minimumTurns(toFit:startDirections:columns:maximumRows:)`` returns the fewest turns,
  0 to 3, with which such a path fits, or `nil` when none does.
- ``Board/occurrences(of:rules:)`` counts ordered paths, folding the two readings of a palindrome
  into one. `strayWords(of:rules:)` scans dictionary prefixes along allowed paths.
- ``Placement/init(word:cells:)`` retains a full ordered path; `direction` describes its first
  segment and `turns` counts its direction changes. Save `cells`, not only `start` and
  `direction`, for turned words. Hints, introduction and selection follow cells; a drag that
  revisits an earlier cell backtracks to it.
- With `rules:` and `maxRows`, generation searches every allowed path, lets no target lie
  entirely on another target's cells, and repeats the search for each board seed in its own
  order. All other rule-based requests inspect at most
  256 shapes and 100,000 search nodes per initial direction and rule and can reject a word when
  that bounded search finds no unique path. A prepared request then freezes its checked shapes
  and board seeds change positions and filler; if all rules have zero turns, generation
  delegates to the straight generator. A checked fallback guarantees target uniqueness;
  dictionary filtering is best effort as with straight boards. Selection keeps its
  start-anchored direction snapping for straight rules.
- Generation keeps the best unique-target ordinary fill within its search budget, preferring
  fewer distinct stray words. It uses the isolated filler only if no ordinary fill has unique
  targets. Noise scoring has a deterministic node budget and prunes already counted dictionary
  words; an exhausted score never counts as clean, and fully scored fills outrank incomplete ones.
- The library keeps one generation. A seed gives the same board within one library version
  only; an app that must keep a board across updates saves its letters and placements.
- ``BoardDictionary`` prepares a reusable dictionary index for many requests.
  ``BoardGenerationLimits/standard`` exposes the unchanged default search bounds.
- ``PathReveal`` turns elapsed time into a growing path prefix, or the complete path for reduced
  motion. The caller owns timing and presentation.

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
- ``WordRule``
- ``BoardGenerationLimits``
- ``BoardDictionary``
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
- ``PathReveal``
