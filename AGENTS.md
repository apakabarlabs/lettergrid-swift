# LetterGrid

Before the first action read the whole wiki «Как мы пишем код»:
https://wikilayer.org/smee-again/codestyle

## Decisions that outlive the current code

- The library is public. Every release gets a tag, a GitHub release and a CHANGELOG entry;
  Lexling and Word by Word take it by released version, and from the sibling directory
  `../lettergrid-swift` only while checking changes not yet released.
- Only what any app with a letter grid needs lives here. A game's own rules — its levels,
  score, hints for points, clock — stay in that app, as Lexling's do in its LexlingGame package.
- The grid, the round and the countdown are plain Swift and are tested on Linux in CI. The
  SwiftUI views sit in their own target behind `canImport(SwiftUI)`, and the colours come from
  the app's theme through `LetterGridStyle`.
