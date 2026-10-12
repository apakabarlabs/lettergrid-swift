# Changelog

## [0.1.0] - 2026-10-12

### Added

- `BoardGenerator` builds a grid of letters that hides each given word exactly once, reading
  left to right or top to bottom, with no other word of a given dictionary readable in it by
  chance. A word too long for the width stands upright and the grid grows downwards.
- `Round` plays one grid: a finger drawn along a word finds it, a drag over no word is
  rejected, a hint opens one letter at a time, the first word can be shown letter by letter,
  and an optional clock can run out. `HintOrder` chooses whether hints open letters from the
  start of a word or anywhere but its first letter.
- `Countdown` drives a round's letter-by-letter introduction and its clock.
- `LetterBoard` and `HiddenWordList` draw a round in SwiftUI, with colours from
  `LetterGridStyle`.
