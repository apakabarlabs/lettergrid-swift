# ``LetterGridUI``

Display a word search in SwiftUI using colours supplied by the application.

## Overview

Create a `Round` from LetterGrid and pass it to ``LetterBoard``. The view observes the
round. Route touch, drag and release callbacks to the state owner so an application can
enforce its own game rules before changing the round. What a game shows around the board,
such as the words to find, is the application's own; it reads `Round.shownLetters(of:)`
and `Round.found`.

``LetterGridStyle`` supplies semantic colours and the rejection display duration.
``LetterHighlight`` draws the same path geometry over custom board content.

### Display options

- `LetterBoard.label` changes each cell's displayed string, allowing another script without
  changing selection or word matching. All labels share a font size based on the longest label.
  Labels run on redraw and should use a prepared lookup table.
- `LetterBoard.missed` highlights a placement after play ends using `LetterGridStyle.rejected`.
  Its path appears above other paths and below letters, without changing the round.
- `LetterBoard.traceCells` displays a caller-controlled ordered path above highlights and below
  letters in `LetterGridStyle.selected`. The caller can pace it with LetterGrid's `PathReveal`.
- `LetterHighlight(cells:cellSize:color:)` draws every segment with rounded turns and endpoints.
  Its `start:end:cellSize:color:` initializer remains available for straight highlights.
- SwiftUI's `textCase` applies to every displayed letter. `.uppercase` expands `և` and `ß`
  into two letters; use `label` when a cell needs a custom capital display.
- `LetterGridStyle.rejectionSeconds` must be a positive representable duration.

## Topics

### Views

- ``LetterBoard``
- ``LetterHighlight``

### Appearance

- ``LetterGridStyle``
