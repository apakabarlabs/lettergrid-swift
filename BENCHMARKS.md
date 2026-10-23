# Performance measurements

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
