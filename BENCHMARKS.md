# Performance measurements

## 2026-10-23: ordinary 7×7 boards with 0.11.0

| Operation | Median, ms | Minimum, ms | Maximum, ms |
|---|---:|---:|---:|
| Generate one board | 2.40 | 2.38 | 2.44 |
| Read hinted cells | 0.00319 | 0.00315 | 0.00334 |
| Create a round and select every answer | 0.00765 | 0.00748 | 0.00772 |

Run `make bench` in release mode. These are measurements of one English word set on an
Apple M1 Pro, 32 GiB RAM, macOS 27.0.1, Apple Swift 6.4, connected to AC power.
Library sources match tag `0.11.0`; benchmark sources are at `db6e7ce`.
They do not measure UI latency or establish a speedup over an earlier version.

### Workload and method

- Three screens: `HOUSE HOME DOOR WINDOW`, `ROOF FLOOR WALL`, `KEY YARD GATE`.
  Each uses seeds 1 through 30, producing 90 boards, all checked to be 7×7.
- Right/down directions, half the answers vertical (rounded either way for three words),
  filler weights proportional to letter frequency across all ten words, `sameNeighbour: 1`,
  all ten words as the dictionary, default search limits.
- Generation includes constructing the generator and request, searching, filling and a
  checksum of the resulting letters. Input spellings and filler weights are prepared
  before timing. Before measurement, every input is checked for exactly one occurrence
  of each answer and no stray dictionary words.
- Hints use `.anyButFirst` and rounds prepared with twice as many `reveal()` calls as answers.
  Round creation and revealing happen before timing; hinted-cell lookup and its checksum are timed.
- Selection includes creating a round without a countdown, getting each placement's last cell, then one
  `touch`, `drag` and `release` per answer. Successful releases and the winning phase are checked
  inside the timed operation. It does not simulate intermediate drag events.
- After one warm-up operation, five samples each execute 90 generation operations or 9,000
  hint/selection operations. Each sample covers the complete 90-board corpus equally.
  The table shows the median and range of those five batch means, not individual-operation
  percentiles or a confidence interval. Checksums: generation `1691725`, hints `8270263`,
  selection `150004`.

## 2026-10-23: 0.10.0 to 0.11.0

**These are synthetic stress cases from one local run, not typical application timings.**
No representative natural-language workload or statistical confidence interval was measured.

Both runs used the same arm64 macOS 27 host and Apple Swift 6.4 during one working session.
CPU model, memory and power state were not recorded. Baseline library sources are at
`b1a084b`; optimized sources are at `a0dfb61`. The benchmark target was added separately
(`dacb097`) and its large-dictionary case in `3a6b76c`.

Run `make bench` for all cases, compiled in release mode. There are no additional parameters.
Each result is the median of five samples after one warm-up call. Scans run three operations
per sample, fallback generation 100, and hint calculation 200. Dispersion was not recorded;
some samples last only 1–3 ms, so small differences may reflect noise. Values below are
rounded to three significant digits and represent milliseconds per operation.

| Case | Before, ms | After, ms | Speedup |
|---|---:|---:|---:|
| Long-prefix scan, 16×16 | 2.3 | 0.838 | 2.7× |
| Long-prefix scan, 32×32 | 23.1 | 3.37 | 6.9× |
| Long-prefix scan, 64×64 | 312 | 23.1 | 13.5× |
| Scan with placements and matches, 16×16 | 7.48 | 1.64 | 4.6× |
| Scan with joining Unicode cells, 18×16 | 14 | 6.56 | 2.1× |
| Fallback, 4 input filler letters | 0.0541 | 0.038 | 1.4× |
| Fallback, 16 input filler letters | 0.114 | 0.0544 | 2.1× |
| Fallback, 26 input filler letters | 0.172 | 0.0685 | 2.5× |
| Hints, 32 letters | 0.012 | 0.00652 | 1.8× |
| Hints, 128 letters | 0.0911 | 0.0249 | 3.7× |
| Hints, 512 letters | 1.04 | 0.0979 | 10.6× |

### Inputs

- Long-prefix scans: all-`A` boards, all eight directions, one dictionary word consisting
  of `side` letters `A` followed by `X`. No matches; no early prefix mismatch.
- Placement scan: an all-`A` 16×16 board, one horizontal 16-letter placement in the first
  row, and the four dictionary words `A`, `AA`, `AAA`, `AAAA`. Its palindrome placement
  excludes intended readings in both directions; other matching readings are returned.
- Unicode scan: 16 rows, each containing six groups of the cells `a`, combining accent,
  `x` (18 cells per row). Dictionary: `á`, `áx`, `x`; all eight directions.
- Fallback: 7×7 minimum board, targets `SUN` and `MOON`, right/down directions, equal weights,
  `sameNeighbour: 0.2`, zero search attempts. Input letters are prefixes of `A...Z`;
  target letters are excluded from filler. Seeds advance from 1 through 501, including warm-up.
- Hints: one all-`A` word, all but its first letter revealed, `anyButFirst` hint order.

An additional case scans a 3×3 `CAT/DOG/SUN` board against 50,003 dictionary entries in
**0.0056 ms/op** (100 operations per sample): `UNRELATED0...UNRELATED49999`, `CAT`, `DOG`,
`SUN`. There is no before or forced-index measurement for this case; it is not an acceleration
claim.

Scan and hint checksums match the baseline. Fallback boards differ intentionally because the
new algorithm consumes fewer random numbers. Its timings compare the same generation task,
with equivalent weighting rules, rather than identical output boards. Compatibility details
are in the [changelog](https://github.com/apakabarlabs/lettergrid-swift/blob/main/CHANGELOG.md).
