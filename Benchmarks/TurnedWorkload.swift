import LetterGrid

struct TurnedWorkload {
  let words: Set<String>
  let rules: [WordRule]
  let weights: LetterWeights

  var generator: BoardGenerator {
    BoardGenerator(
      size: BoardSize(columns: 7, rows: 7, maxRows: 7),
      rules: rules,
      filler: Filler(weights: weights),
      limits: PlacementLimits(downWords: 1...2)
    )
  }
}
