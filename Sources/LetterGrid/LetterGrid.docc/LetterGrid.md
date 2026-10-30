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

Words use ``Swift/String/cellUppercased``: each grapheme is one cell in NFC, and a
capital that expands to multiple characters leaves the original character in its single
cell. The fixture `cell-text.yaml` pins this for every port. Use this form when
comparing application words with board words. The same seed and configuration produce
the same board within one library version. Save letters and placements when a board
must retain its layout across library updates.

Prepare words once using ``BoardGenerator/request(for:firstDirection:firstRule:)`` and build them
through ``BoardRequest`` using `board(seed:dictionary:)`. The request retains its checked settings;
an optional dictionary can be supplied at build time. Empty word lists and invalid generator
configuration are rejected before a request is returned.

For candidate selection, ``BoardGenerator/checkPlacement(for:firstDirection:firstRule:)``
and ``BoardGenerator/checkPlacement(for:leadingRules:)`` search target paths without
filling the remaining cells. They enforce the same word, path, quota, character-copy
and target-run constraints as request preparation. They return no request or board.
A successful placement check can still be followed by `unsettled` from the full
`request` when filler cannot complete the layout. Prepare the selected words and
handle that failure before presenting a board. Existing `request` calls continue
to retain a checked fallback for nonthrowing seeded builds.
Use `accepts` for preliminary word, geometry and quota checks, `checkPlacement` for
a joint placement search, and `request` to prepare a complete board. A placement
check does not retain reusable work: `request` repeats placement before filling.

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
  retain a run-free fallback and throw `unsettled` if preparation cannot find one.
- Directions are opt-in. The vertical quota counts only `.up` and `.down`, including turned
  words whose first segment runs up or down; their serialized
  names are the case names, while diagonals use `down_right`, `down_left`, `up_left` and `up_right`.
- Both generator initializers accept ``BoardGenerator/maxWordsPerDirection``: an optional
  positive maximum number of targets starting in each direction. Turned words count by
  their first segment, as reported by ``Placement/direction``; opposite directions count
  separately. Leading words count toward the same limit. The default `nil` is unlimited
  and preserves 0.21.0 generation. This constraint is independent of `downWords`
  and applies to preliminary checks, joint placement, preparation and seeded repacking.
  ``BoardRequest/maxWordsPerDirection`` retains the requested limit. A nonpositive limit
  makes `accepts` return false and throwing preparation or placement checks report
  `invalidConfiguration`; words exceeding the available direction capacity throw `noRoom`.
- A palindrome occurs once even when both directions of its line are enabled, and can be
  selected from either end. Selection snaps to the nearest allowed direction. With diagonals
  enabled, a gesture must be within 22.5 degrees of an allowed direction.
- Requests reject empty target lists, words shorter than two letters, duplicates after
  uppercasing and words contained in other targets. When opposite directions are enabled,
  reverse containment is also rejected. Directions must satisfy the vertical quota and any
  required first direction. Filler may consist entirely of letters present in the targets;
  preparation still checks target uniqueness, character copies and the rules against added runs.
- Dimensions must be positive, rules valid and the vertical minimum nonnegative; invalid
  settings throw ``BoardGenerator/Failure/invalidConfiguration``. Incompatible words throw
  ``BoardGenerator/Failure/noRoom(words:columns:rows:)``.
- One search lays out every request, straight or turned: it tries every allowed path of every
  word, lets no target lie entirely on another target's cells, and prefers places where a
  word shares letters with the words already placed. When a layout comes out with no shared
  letter although the words have letters in common, it searches again in another order, up
  to eight times, and keeps the layout that shares most. Each board seed repeats the search in
  its own order, so seeds vary where the words lie.
- An optional `maxRows` must be at least `rows`; set both to the same value for an exact
  height. Within a height limit the search is complete: `noRoom` means that no layout exists,
  and ``BoardGenerator/Failure/unsettled(words:columns:rows:)`` that the search ran out first.
  `unsettled` also reports words that do fit, but only in layouts where the targets themselves
  put three equal letters in a line, and words whose layout no filler can complete without
  such a line. Without `maxRows` the board grows downwards to the lowest height the search
  places the words at within a smaller budget per height.
  ``BoardGenerator/accepts(_:firstRule:)`` checks the word conditions and the vertical quota
  without a board; a set it rejects always throws, and a set it accepts may still have no
  layout. Read the resulting height from `board.rows`.
- Filler weights must be positive and finite. `sameNeighbour` in `(0, 1]` multiplies a letter's
  weight once per equal neighbour in the eight surrounding cells. Its default is `1`; extreme
  weights are rescaled when needed for valid sampling.

### Restoring and pacing

Every character of the target words, letters, nonletter characters and
`conditionalCharacters` alike, occupies at least two cells of the board. A character that
the target paths already hold twice gets no copy; any other gets one copy in a free cell.
Ordinary weighted fill excludes nonletter and conditional characters, so a conditional
character absent from the targets never appears on the board. Requests reject layouts
that leave fewer free cells than copies.

- ``WordRule`` enables zero to three exact 90-degree turns in either direction, without
  revisiting cells. Its directions apply to the first segment. Supply rules to both the
  generator and round. `firstRule` requires the first word to use one particular enabled rule.
  With a generator created using `rules:`, ``BoardGenerator/request(for:leadingRules:)``
  assigns `leadingRules[i]` to `words[i]`, leaving later words free to use any enabled rule.
  A leading rule can use a subset of an enabled rule's starting directions with the same
  turn count. Invalid or disabled rules throw `invalidConfiguration`; more rules than words,
  an impossible leading path or an incompatible vertical quota throw `noRoom`. The placement
  and fill searches can still throw `noRoom` or `unsettled`, as for an unconstrained request.
  ``BoardRequest/leadingRules`` retains every constraint for seeded builds;
  `firstRule` returns its first element. An empty list adds no constraints.
  ``BoardGenerator/accepts(_:leadingRules:)`` performs the preliminary word, geometry and
  quota checks only, and returns false for invalid or disabled leading rules.
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
- Selection keeps its start-anchored direction snapping for straight rules.
- The fill keeps targets unique and prefers fewer distinct stray words from the dictionary,
  which is best effort. Noise scoring has a deterministic node budget and prunes already
  counted dictionary words; an exhausted score never counts as clean, and fully scored fills
  outrank incomplete ones.
- The library keeps one generation. A seed gives the same board within one library version
  only; an app that must keep a board across updates saves its letters and placements.
- Every random choice draws from ``SeededRandom`` through its own methods, never through the
  standard library's algorithms; its page states each algorithm for a port.
- ``BoardDictionary`` prepares a reusable dictionary index for many requests.
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
