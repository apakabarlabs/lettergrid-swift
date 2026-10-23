# ``LetterGridUI``

Display a word search in SwiftUI using colours supplied by the application.

## Overview

Create a `Round` from LetterGrid and pass it to ``LetterBoard`` and
``HiddenWordList``. The views observe the round. Route touch, drag and release callbacks
to the state owner so an application can enforce its own game rules before changing
the round.

``LetterGridStyle`` supplies semantic colours and the rejection display duration.
The application supplies the hidden-word accessibility label in its own language.
``LetterHighlight`` draws the same path geometry over custom board content.

A cell label can replace a character with a display string without changing selection
or word matching. Labels run on redraw and should use a prepared lookup table.

## Topics

### Views

- ``LetterBoard``
- ``HiddenWordList``
- ``LetterHighlight``

### Appearance

- ``LetterGridStyle``
