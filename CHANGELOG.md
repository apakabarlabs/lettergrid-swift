# Changelog

## [0.22.0] - 2026-10-30

Existing callers need no changes. Omitting the new limit, or passing `nil`, preserves
0.21.0 generation, including seeded layouts. No saved-game migration is needed.

### Added

- Both `BoardGenerator` initializers accept `maxWordsPerDirection: Int? = nil`.
  Set it to a positive number to cap how many targets start in each direction.
  Turned words count by their first segment (`Placement.direction`); opposite
  directions count separately. Leading words count toward the same cap.
- The cap applies to `accepts`, `checkPlacement`, complete request preparation and
  every seeded board, with fixed or growing height. A nonpositive cap makes
  `accepts` return false and throwing checks report `invalidConfiguration`.
  Insufficient direction capacity reports `noRoom`; layout and fill searches retain
  their existing `noRoom` and `unsettled` failure modes. Preliminary acceptance alone
  still does not guarantee a joint layout or successful fill.
- `BoardRequest.maxWordsPerDirection` exposes its retained cap. Generator and request
  equality include it. The existing `downWords` API remains available and independent:
  when both constraints are supplied, a board must satisfy both.

## [0.21.0] - 2026-10-30

Existing callers need no changes. `request` and `board(seed:)` keep their 0.20.0
behavior; no saved-game migration is needed.

### Added

- `BoardGenerator.checkPlacement(for:firstDirection:firstRule:)` and
  `checkPlacement(for:leadingRules:)` tell whether a set of words fits on the board
  together, without filling the remaining cells. Both are instance methods, as `request`
  is, and `firstDirection:` and `firstRule:` default to `nil`. A check that returns
  without throwing means the words fit; otherwise it throws what `request` with the
  same arguments would throw while placing the words:
  - `invalidConfiguration` for arguments `request` refuses: `firstDirection` on a
    generator created with `rules:`, `firstRule` on one created with `directions:` (so
    pass at most one of the two), a `firstRule` that is not one of the generator's
    rules, a leading rule the generator's rules do not allow, or `leadingRules` on a
    generator created with `directions:`;
  - `noRoom(words:columns:rows:)` when the words cannot be placed together;
  - `unsettled(words:columns:rows:)` when every placement found puts three equal letters
    in a line across the hidden words themselves, before any filler is added.

  The check applies everything `request` applies while placing: the same normalized
  words, direction and turn rules, `downWords` quota and search limits. So a set that
  `request` accepts always passes the check with the same arguments. The reverse does
  not hold: `request` can still throw `unsettled` when no filler avoids three equal
  letters in a row, so be ready to pick another candidate then.

  Use the check to filter several candidate word sets, then call `request` for the one
  you pick. `request` repeats the placement, because the check keeps nothing. Unlike
  `accepts`, which runs quick checks without laying the words out, the check searches
  for a joint placement and takes as long as that search, so run it off the main thread
  when filtering many sets.

## [0.20.0] - 2026-10-30

Existing callers need no changes. Calls that worked in 0.19.1 produce the same board with
the same words, settings and seed. The `firstRule:` and `firstDirection:` overloads remain
available and are not deprecated; `leadingRules:` is a separate overload, not an additional
argument to either.
The new `leadingRules:` argument is required, so calls that omit it remain unambiguous.
There is no serialized `BoardRequest` format to migrate.

### Added

- `BoardGenerator.request(for:leadingRules:)` assigns rule 0 to word 0, rule 1 to word 1,
  and so on, for as many rules as you pass. Later words may use any rule from the
  generator's `rules:`. This overload requires a generator created with `rules:`;
  a generator created with `directions:` throws `BoardGenerator.Failure.invalidConfiguration`.
  For example, require different directions for the first two of three words:

  ```swift
  let generator = BoardGenerator(
    columns: 7, rows: 7,
    rules: [WordRule(startDirections: [.right, .down], turns: 0)],
    filler: try LetterWeights(["x": 1, "q": 1]))
  let request = try generator.request(
    for: ["cat", "dog", "sun"],
    leadingRules: [
      WordRule(startDirections: [.right], turns: 0),
      WordRule(startDirections: [.down], turns: 0),
    ])
  let board = request.board(seed: 42)
  ```

  Each leading rule must have nonempty `startDirections` and a turn count from 0 through 3.
  Some rule in the generator's `rules:` must contain all its directions and have the same
  turn count; otherwise the call throws `BoardGenerator.Failure.invalidConfiguration`.
  More leading rules than words, words that cannot meet the constraints, or constraints
  incompatible with `downWords` throw `BoardGenerator.Failure.noRoom`. `downWords` still
  counts all words whose first segment runs up or down. If the search cannot find a complete
  board with unique targets and no added runs of three equal letters within the library's
  built-in search limits, the call throws `BoardGenerator.Failure.unsettled`. These limits
  are not caller-configurable. An empty list gives an equal request and the same boards
  as `request(for:)` on the same generator.
  For an existing `firstRule: rule` call, `leadingRules: [rule]` returns an equal request
  and produces the same boards for the same seeds.
- `BoardGenerator.accepts(_:leadingRules:)` returns `false` for leading rules that fail the
  checks above, more rules than words, empty target lists, words shorter than two cells, duplicate
  or contained target words, unusable filler, a word whose path cannot fit the dimensions,
  or an incompatible `downWords` range. `true` means it passed only these preliminary checks:
  `request` may still fail to place all words together or fill the remaining cells.
- `BoardRequest.leadingRules` is a read-only array of the rules requested for the leading
  words. With the old overloads it contains `[rule]` for `firstRule: rule`, a zero-turn rule
  for `firstDirection: direction`, or `[]` when neither constraint is supplied. The existing
  `BoardRequest.firstRule` property returns the first element, or `nil` for an empty list;
  its behavior for old calls is unchanged. For the new overload, comparing `firstRule`
  alone does not compare all constraints; request equality includes the whole array.
  Every board built from that request follows all these rules.

## [0.19.1] - 2026-10-29

### Fixed

- `accepts` and `request(for:)` no longer reject a word set just because its target words
  collectively use every letter in the filler alphabet. For example, `AB`, `CD` and `EF`
  can share a board filled from `ABCDEF`.
  Target uniqueness, two cells per target character and the rules against added runs of
  three equal letters still apply. `request(for:)` throws `BoardGenerator.Failure.unsettled`
  if it cannot find a fill that meets those guarantees. Previously accepted requests keep
  their seeded boards.

## [0.19.0] - 2026-10-29

To upgrade from 0.18:

- Remove `generationVersion:`, `layoutsPerAttempt:`, `attempts:` and `fillsPerAttempt:`
  from every `BoardGenerator` you create, and drop any stored generation version (see
  Removed).
- A seed gives a different board than it did in 0.18. If a player must see the same board
  after updating the app, save the board itself (its letters and placements) before the
  update and restore it with `Board(validating:placements:)`. A game that keeps only a
  seed will show a new board.
- `request(for:)` may throw `BoardGenerator.Failure.unsettled` (the words could not be
  placed and filled within the generator's search limits) for some setups it accepted
  before, for example a filler of a single letter (see Changed). Handle it like `noRoom`:
  pick other words or a larger board.
- If you compare your own word strings with board words, uppercase them with
  `cellUppercased`: it now also normalises to Unicode NFC.

### Changed

- Every character of the hidden words appears on the board at least twice, so a player
  cannot find a word just by spotting a letter, space or hyphen that occurs only once. A
  character that already occurs twice inside the hidden words gets no extra copy. The
  copies take free cells, so a board with a fixed height (`maxRows`) and too few free
  cells throws `noRoom`, and a board without `maxRows` grows taller.
- The random letters around the hidden words never form three equal letters in a row,
  column or diagonal, and avoid two equal neighbours whenever the board can be filled
  without them. Three equal letters in a line remain only where a hidden word itself
  has them.
- `request(for:)` checks that a board with these properties can be filled before it
  returns, and throws `unsettled` when it cannot. This includes filler alphabets that can
  only fill the board with three equal letters in a line, such as a single filler letter.
  `board(seed:)` still never throws.
- `cellUppercased` returns each cell in Unicode NFC (composed form), so `e` followed by a
  combining accent becomes the single character `é`.
- All requests, with or without `maxRows`, place words with the same search. It prefers
  positions where words share letters, and without `maxRows` it grows the board only to
  the smallest height that fits. `accepts(_:firstRule:)` now also returns false when the
  words cannot satisfy the generator's `downWords` range (how many words must run
  vertically).
- Requests from generators created with `rules:` and `maxRows` are prepared faster.
- The library reads its internal search limits from a resource file bundled inside the
  package, and parses it with the Yams package, which SwiftPM now fetches as a
  dependency. No code change is needed.

### Removed

- `BoardGenerationVersion` and the `generationVersion:` parameter of `BoardGenerator`. The
  library no longer reproduces the boards of earlier versions. Remove the argument and
  any stored version:

  ```swift
  // 0.18
  let generator = BoardGenerator(
    columns: 7, rows: 7, directions: [.right, .down], filler: weights,
    generationVersion: savedVersion)
  // 0.19
  let generator = BoardGenerator(
    columns: 7, rows: 7, directions: [.right, .down], filler: weights)
  ```

- `BoardGenerationLimits` and the `layoutsPerAttempt:`, `attempts:` and `fillsPerAttempt:`
  parameters of `BoardGenerator`. Generation no longer makes repeated attempts, so there
  is nothing for them to limit. Remove the arguments.

### Added

- `SeededRandom.nextInt(below:)`, `nextInt(in:)`, `nextDouble(below:)`, `shuffled(_:)` and
  `pick(_:)`: seeded random draws whose algorithms are spelled out in the `SeededRandom`
  documentation, so that the same seed gives the same numbers in any reimplementation.
- `Placement(validating:cells:)` throws `Board.Failure.invalidPlacement` for cells that do
  not form a word path, instead of crashing, so a corrupted saved board can be rejected
  safely.

### Fixed

- Board generation no longer depends on details that can differ between platforms
  (floating-point math functions, the order of equal items after sorting, string
  comparison), so the same seed builds the same board on every platform. This fix on its
  own does not change boards on Apple platforms; the changes listed above do.
- Words containing spaces, hyphens, apostrophes or characters you pass in
  `conditionalCharacters:` could make `request(for:)` run for a very long time on a large
  board. That work now counts toward the same search limit as placing the words, and
  running out of it throws `unsettled`.
- `LetterWeights` treats keys that differ only in case, such as `"a"` and `"A"`, as one
  letter and adds their weights: `["a": 1, "A": 2]` now equals `["a": 3]`. Boards built
  with such weights change, and weights whose merged sum overflows throw
  `LetterWeights.Failure.notFinite`.

## [0.18.1] - 2026-10-27

### Changed

- `request(for:)` on a `BoardGenerator` built with `rules:` and `maxRows` is about twice as
  fast, in debug and release builds alike: three words on a 7 × 7 field take half the time
  `make bench` measures for 0.18.0. It returns the same boards and throws
  `BoardGenerator.Failure` for the same words as 0.18.0, so nothing changes in your code.

## [0.18.0] - 2026-10-27

### Changed

- Source-breaking: `BoardGenerator.Failure` has a new case, `unsettled`, so an exhaustive
  `switch` over it no longer compiles until it handles that case:

  ```swift
  // 0.17
  case .noRoom: chooseOtherWords()
  case .invalidConfiguration: fixSettings()
  // 0.18
  case .noRoom, .unsettled: chooseOtherWords()
  case .invalidConfiguration: fixSettings()
  ```

- `BoardGenerationVersion.current` is now the new `v0p18`, stored as `"0.18"` when encoded.
  LetterGrid 0.17 and earlier cannot decode that value.

The remaining items of this section apply only to a `BoardGenerator` built with `rules:` and
`maxRows` under `v0p18`, the default version of a new generator. They apply even when every
rule has zero turns: such a generator no longer hands its words to the straight generator, as
it does from 0.12 to 0.17. A generator built with `directions:` or without `maxRows`, or pinned
to `v0p9`, `v0p12`, `v0p13` or `v0p17`, makes the same boards as in 0.17.

- Boards made from a saved seed differ from 0.17. To keep them, pass
  `generationVersion: .v0p17` to the `BoardGenerator` initializer, or save the letters and
  placements of each board.
- `request(for:)` tries every path each word can take under the rules, at every position on
  the grid, instead of a random sample of `layoutsPerAttempt` layouts; that setting is
  ignored, while `attempts` and `fillsPerAttempt` still bound the filling. Many sets that 0.17 refused now get
  a board: in a sample of 771 three-word sets that 0.17 refused on a 7×7 grid with one turn
  allowed, taken from a word game's vocabularies, 593 now fit and the search proved the other
  178 cannot. Words still cross only on equal letters, the first word still follows `firstRule`,
  the count of vertical words stays in `downWords`, and each word still reads once. The search
  works for any number of words; tests cover one to five. It visits layouts in a fixed order, so
  asking again for the same words gives the same answer.
- No word may use only cells that another word also uses, whichever way either is read and
  however the cells lie along the other word's path. Such a layout is skipped, and
  `request(for:)` throws `noRoom` when no other layout exists. 0.17 checks this only on the text
  of the words, before any layout is tried.
- `noRoom` thrown by `request(for:)` now means that the set breaks a condition that
  `accepts(_:firstRule:)` checks, or that the search proved no layout exists.
- `board(seed:)` runs the layout search of `request(for:)` again, visiting layouts in an order
  set by the seed, so seeds still place words differently. It never throws: if that search
  reaches the limit of two million candidate placements described below, the board uses the
  layout that `request(for:)` found. The search has no clock timeout, only that limit. In the
  sample above one search, in `request(for:)` or in `board(seed:)`, took at most two seconds in a
  debug build on an Apple silicon Mac; call both off the main thread.
- Nonletter characters such as hyphens, and `conditionalCharacters`, still get extra copies
  outside the words, as in 0.17. Their cells are now chosen during the layout search by trying
  every way to place them; a set that leaves no room for them throws `noRoom`. A seed therefore
  never falls back to another seed's board: in 0.17 a seed whose random placements of the copies
  all failed received the board of seed 0.

### Added

- `BoardGenerator.accepts(_ words: [String], firstRule: WordRule? = nil) -> Bool` checks a
  word set without building a board, under any generation version. It compares words after
  `cellUppercased` and checks that they are distinct and at least two letters long, that none
  contains another as text in the same direction, that each word alone has a path under the
  rules within `columns` and `maxRows`, or of any height when `maxRows` is `nil` (the first word
  under `firstRule` when given). It does not
  check reversed text, `downWords` or the overlap rule above. When it returns `false`,
  `request(for:firstRule:)` throws `noRoom` under every version. When it returns `true`, a
  layout may still not exist.
- `BoardGenerator.Failure.unsettled(words:columns:rows:)` is thrown only by
  `request(for:firstRule:)` of the generators described under Changed, when the search tries two
  million candidate path placements, a limit that cannot be changed, before it finds a layout or
  proves there is none. `words` holds the words after `cellUppercased`; `rows` carries
  `maxRows`. None of the 771 sets above reached the limit.

## [0.17.0] - 2026-10-27

- Nonletter target characters remain cells of their full word paths. Generation 0.17 adds
  at least one additional copy of every such character outside all target paths.
- `BoardGenerator.conditionalCharacters` applies the same policy to caller-selected letters:
  they never appear in ordinary fill when absent from the targets. Checked requests retain
  a fallback with unique targets and the required extra copies, or reject when no checked
  placement leaves room for them. Rejection throws `BoardGenerator.Failure.noRoom`;
  provide more room or choose words whose required copies fit outside their paths.
- `BoardGenerationVersion.current` is now `v0p17`; explicit 0.9, 0.12 and 0.13 generation
  retains its released behavior. Ordinary targets without conditional characters retain
  their existing seeded boards.

## [0.16.0] - 2026-10-27

### Added

- `WordRule.minimumTurns(toFit:startDirections:columns:maximumRows:)` is a static function:
  given a word length (`toFit`), the directions its first segment may take, the grid width
  and an optional height limit, it returns the fewest 90-degree turns, from 0 to 3, with
  which one path of that length fits an empty grid. It returns `nil` when no supported
  turn count fits. It asks `canFit(length:columns:maximumRows:)` for each turn count in
  turn, so it shares that check's limits: no letter content, no packing of several words,
  a `nil` height limit allows vertical growth, and the answer is deterministic.
  On a 7×7 grid the longest word that fits, starting right, has 7 letters straight,
  13 with one turn, 19 with two and 24 with three.
- `WordRule.supportedTurns` is the `ClosedRange<Int>` `0...3` of turn counts a rule may have.
- The package now declares Yams 6.2.2 or later for its tests. SwiftPM resolves it for
  packages that depend on LetterGrid as well, though no LetterGrid target links it.

Existing calls need no changes.

## [0.15.0] - 2026-10-26

### Added

- `WordRule.canFit(length:columns:maximumRows:)` checks whether one path of the given
  length fits an empty grid, with the rule's exact turn count. A missing height limit
  permits vertical growth. The check is deterministic and has no search budget;
  cache it per rule, word length and dimensions. It does not check letter
  content, packing several words together or generation quotas, so a fitting word
  can still be rejected by `BoardGenerator.request(for:)`. Existing generation and
  seeded layouts are unchanged; existing callers need no changes.

## [0.14.0] - 2026-10-26

### Added

- `BoardGenerator.maxRows` optionally limits board height for straight and turned paths.
  Set `maxRows` equal to `rows` for an exact height. With the limit set, `request(for:)`
  returns only after preparing a checked unique-target fallback within the limit.
  Bounded preparation can throw `noRoom` even when another packing could fit.
  Dictionary filtering remains best effort.
- Bounded `.v0p13` straight generation retains an ordinary unique-target fill with the
  least dictionary noise found within its search budget, before using isolated filler.
- The limit must be at least `rows` and is unavailable for `.v0p9`. Omitting it preserves
  previous generation behavior and seeded layouts. Existing calls need no changes.

## [0.13.1] - 2026-10-26

### Fixed

- Split benchmark input construction into smaller typed expressions so Swift 6.2 on Linux
  can compile the benchmark target during `make test`. Library behavior is unchanged.

## [0.13.0] - 2026-10-26

### Changed

- Turned boards prefer an ordinary weighted fill with unique targets and the fewest distinct
  stray dictionary words found within the configured search budget. A clean fill still returns
  immediately. The isolated filler is reserved for searches with no unique-target ordinary fill.
  Dictionary filtering remains best effort; target uniqueness remains mandatory.
- This changes turned seed layouts. `BoardGenerationVersion.current` now names `.v0p13`
  (Codable value `0.13`). Use `.v0p12` with the original settings and words for seed-only 0.12
  games. Straight generation and `.v0p9` restoration keep their previous behavior.

### Added

- `BoardDictionary(words)` and the prepared-dictionary overload of `BoardRequest.board` reuse
  one normalized index across boards: `let dictionary = BoardDictionary(words)`, then
  `request.board(seed: seed, dictionary: dictionary)`. Existing word-set calls remain available.
- `BoardGenerationLimits.standard` exposes the existing default attempt, fill and layout bounds.
- Dictionary checks stop at the first disqualifying word. Distinct noise scoring prunes counted
  word subtrees and bounds node visits; exhausting its work budget never declares a board clean.
  Path scanning reuses a path buffer and visited-cell storage.
  A completely scored fill is preferred to an unscored fill. If every unique-target ordinary
  fill exhausts scoring, the first one is retained; this does not trigger the isolated filler.

## [0.12.0] - 2026-10-25

### Added

- Word paths can make zero to three 90-degree turns in either direction without revisiting cells.
  Pass `WordRule(startDirections:turns:)` values through `rules:` to both `BoardGenerator` and
  `Round`. The turn count is exact; directions describe the first segment. A request's optional
  `firstRule:` applies one enabled rule to the first word. The vertical quota counts first segments.
  Diagonal turns remain diagonal, for example ↘ can turn to ↙ or ↗.
- `Placement(word:cells:)` preserves an ordered path, with `direction` describing its start and
  `turns` its number of bends. Save those cells for turned words. Rule-based occurrence and stray-word
  scans, drag backtracking, hints and introductions follow the same paths. Accepted requests retain
  a fallback with unique targets; dictionary filtering remains best effort.
  Restore a turned round by saving its letters, ordered placement cells, rules and progress, then
  calling `Round(restoring: savedProgress, board: savedBoard, rules: savedRules)`.
- SwiftUI highlights follow every segment. `LetterHighlight(cells:cellSize:color:)` draws paths over
  custom content; `LetterBoard.traceCells` shows an externally controlled trace above highlights
  and below letters. `PathReveal` computes a timed prefix and respects reduced motion. Existing
  straight-highlight calls remain available, and colours still come from the app.
- `BoardGenerationVersion` provides stable Codable identifiers `0.9` and `0.12` (`.v0p9` and
  `.v0p12`). Its `current` value is `.v0p12`. For seed-only rounds created with 0.9, use the
  `directions:` generator with `generationVersion: .v0p9` and the original settings and words
  before saving complete boards. The default `directions:` generator keeps 0.11.1 behavior.
  With only zero-turn rules, generation delegates to the straight generator, preserving layouts
  for its derived directions, original settings and equivalent first-word constraint. When a
  turned rule is enabled, the new generator freezes checked path shapes in each prepared request;
  board seeds vary positions and filler. There is no
  identifier for 0.10: materialize its seed-only boards with that release before updating.
  Seed-only boards from 0.11 use the `directions:` generator with `.v0p12` and original settings.

## [0.11.1] - 2026-10-23

### Added

- Reproducible 7×7 performance measurements with natural-language words and timing ranges.
  Run `make bench`; results and methodology are in
  [BENCHMARKS.md](https://github.com/apakabarlabs/lettergrid-swift/blob/main/BENCHMARKS.md).
  Library behavior and public API are unchanged; no application changes are needed.

## [0.11.0] - 2026-10-23

### Changed

- **Seed compatibility:** fallback filler can differ from 0.10.0 for the same seed, including
  with the default `sameNeighbour: 1`. Boards found by the bounded search keep their previous
  letters and placements; only fallback filler changes. The API does not mark fallback boards,
  so apps rebuilding saved boards from seeds must account for this change.

  A seed alone does not guarantee an identical board across library versions. Preserve a round
  by saving its letters and placements and reloading them with `Board(validating:placements:)`.
  If only seeds were saved, rebuild all such boards with the library version and settings that
  created them, then save their letters and placements before upgrading. Saved `RoundProgress`
  remains usable with that same saved board through `Round(restoring:board:directions:...)`.
  Weights and neighbour penalties retain their meaning. Public call signatures are unchanged
  in 0.11.0.

### Fixed

- Dictionary scans and hint display are faster on long rows and words, with unchanged results.

## [0.10.0] - 2026-10-23

### Changed

- A prepared board request now retains the settings it was checked against. Build it directly
  instead of passing it to a second generator. The old `board(for: request, seed:)` overload
  was removed:

  ```swift
  // Before
  let board = generator.board(for: request, seed: seed)

  // Now
  let board = request.board(seed: seed)
  // A dictionary may still be supplied after checking the words.
  let boardWithDictionary = request.board(seed: seed, dictionary: dictionary)
  ```

  The convenience `generator.board(for: words, seed:)` is unchanged. Requests remain
  equatable and safe to pass between tasks; equality includes their generation settings.
- `Countdown.run` now throws sleep failures, invalid intervals and callbacks that do not
  advance the round. Add `try` and handle errors at the owner of the operation. Cancellation
  still ends normally, without an extra introduction or tick callback.
  The introduction callback must change the introduced cells or leave the introduction phase;
  the tick callback must change the remaining seconds or leave the playing phase. Otherwise
  they throw `Countdown.Failure.noIntroductionProgress` or `.noClockProgress`, respectively.
- Nonthrowing board and round initializers now stop on a failed precondition for invalid
  row widths, placements, progress or unselectable directions. Use the new throwing
  initializers below for stored or otherwise external data so their errors can be handled.

### Added

- `Board(validating:placements:)`, `Round(restoring:board:directions:...)` and
  `RoundProgress.validate(for:)` report malformed boards or saved progress without clearing
  it. Checks include row widths, placement contents, unknown or repeated found words,
  revealed-letter counts, negative seconds and directions that make a word unselectable.
- Published API references for [LetterGrid](https://apakabarlabs.github.io/lettergrid-swift/documentation/lettergrid/)
  and [LetterGridUI](https://apakabarlabs.github.io/lettergrid-swift/ui/documentation/lettergridui/).

### Fixed

- Extreme finite filler weights and neighbour penalties no longer crash sampling through
  overflow or underflow. Non-finite weights are rejected.
- Fallback boards now apply the same neighbour penalty as searched boards. With a penalty
  below one, fallback filler may change for the same seed. As with earlier updates, save
  letters and placements to preserve a round instead of regenerating it from its seed.
- A round restored with an enabled countdown at zero is lost immediately. An empty board is already complete,
  and an empty target list cannot become a playable request.
- Invalid generator dimensions, directions and search limits are reported while preparing
  a request. A drag far beyond the board now does work bounded by the board dimensions.
- Empty or zero-width SwiftUI boards no longer convert invalid gesture coordinates to integers.

## [0.9.0] - 2026-10-23

### Changed

- Among sampled layouts with the same number of rows, generation now prefers the one
  sharing the most letters between words. Previously it kept the first shortest layout,
  even when a later layout crossed words without adding rows. Search limits and public
  call signatures are unchanged; the search still does not guarantee maximum crossings.
  A board rebuilt from a seed may differ from 0.8.0. If an app rebuilds a saved round
  from its seed, its letters may move after updating. An app that reloads saved letters
  and placements without regenerating the board keeps the same layout.

## [0.8.0] - 2026-10-22

### Fixed

- A letter whose `uppercased()` gives more than one Swift `Character`, such as Armenian `և`
  (`ԵՒ`) or German `ß` (`SS`), now takes one cell and is kept as written, in lowercase.
  Every other letter is uppercased as before.

  Before, a word with such a letter took one cell more than it has letters: `ԵՒ` sat in
  two cells, and the player had to drag across both. A filler weight for it was added to
  the first letter of its capital: `"ß": 1` raised the weight of `S`, and `ß` never
  appeared as filler.

  What changes for you only if your words, dictionary or filler hold such a letter:

  - the word is one cell shorter, so for the same seed the board differs from 0.7.0. A
    `Board` built from letters and placements an app saved under 0.7.0 plays as before; an
    app that rebuilds its boards from a seed gets the new board;
  - a filler with such a letter now fills cells with the letter itself under its own
    weight, so filler differs for the same seed even when no word holds the letter;
  - duplicate and contained-word checks in `request(for:firstDirection:)` and the
    dictionary check for words read by chance compare the new form: `straße` and
    `strasse` are now two different words, as are `straße` and `STRASSE`;
  - app code that compares a word with the board through `uppercased()` no longer matches
    such a word; switch it to `cellUppercased`;
  - a `label` table keyed by the board's letters needs an entry for `և` itself;
  - SwiftUI `.textCase(.uppercase)` on the board still draws `ԵՒ` inside the one cell; to
    show such letters differently, pass a `label`.

### Added

- `cellUppercased` on `String` (returns `String`) and on `Character` (returns `Character`)
  gives the form the board holds. Use it wherever the app compares or spells a word next
  to the board, for example a list of found words:

  ```swift
  "երևան".cellUppercased  // "ԵՐևԱՆ", five letters, five cells
  ```

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
  With a smaller factor the filler letters differ, and now and then where the words stand.
  To preserve an existing seed-only game, generate and save its letters and placements
  with the old settings before changing the factor. Already saved letters and placements
  remain unchanged.

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
- Boards the search finds are the same as in 0.4.0. A fallback board regenerated from the
  same seed differs. To preserve a seed-only game, generate and save its letters and
  placements with 0.4.0 before upgrading. Already saved letters and placements remain
  unchanged.

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
