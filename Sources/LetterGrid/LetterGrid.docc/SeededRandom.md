# ``LetterGrid/SeededRandom``

## Overview

Every random choice in generation and in hint order comes from these methods, and their
algorithms are part of the board contract: a port that implements them exactly, on top of
the same `next()`, builds the same boards. The fixture `seeded-random.yaml` pins their output.
Do not substitute a platform's own helpers, such as Kotlin's `Random.nextInt(until)` or
`shuffle`, even where the names match: they draw differently.

- `next()` is SplitMix64: add `0x9E3779B97F4A7C15` to the state, then
  `z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9`, `z = (z ^ (z >> 27)) * 0x94D049BB133111EB`,
  `z ^ (z >> 31)`, all in wrapping unsigned 64-bit arithmetic with logical shifts.
- `nextInt(below: n)` takes the high 64 bits of the 128-bit product `next() * n`. When the
  low 64 bits are below `n`, it computes `t = (2^64 - n) mod n` and draws again while the
  low bits are below `t`. One draw for most values; a bound of 1 still draws once.
- `nextInt(in: a...b)` is `a + nextInt(below: b - a + 1)`; the range must hold fewer than
  `Int.max` values.
- `nextDouble(below: x)` keeps the low 53 bits of `next()`, multiplies them by `2^-53` and
  then by `x`, and draws again while the result equals `x`.
- `shuffled(_:)` is a forward Fisher-Yates shuffle: for `i` from the first position while more
  than one element remains, swap position `i` with `i + nextInt(below: remaining)`; an array
  of `n` elements uses `n - 1` draws, and a swap with itself still draws.
- `pick(_:)` returns `elements[nextInt(below: count)]` with one draw, and `nil` without
  drawing for an empty array.
