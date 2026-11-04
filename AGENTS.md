# LetterGrid

Before the first action read the whole wiki «Как мы пишем код»:
wikilayer://wikilayer.org/smee-again/codestyle

## Decisions that outlive the current code

- The library is public. Every release gets a tag, a GitHub release and a CHANGELOG entry,
  made by `make release`; apps take it by released version, and from a sibling directory
  only while checking changes not yet released.
- Only what any app with a letter grid needs lives here. A game's own rules — its levels,
  score, hints for points, clock — and what it shows around the board stay in that app.
- The grid, the round and the countdown are plain Swift and are tested on Linux in CI. The
  SwiftUI views sit in their own target behind `canImport(SwiftUI)`, and the colours come from
  the app's theme through `LetterGridStyle`.
