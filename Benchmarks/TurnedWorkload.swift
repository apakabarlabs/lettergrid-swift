import LetterGrid

struct TurnedWorkload {
  let words: Set<String>
  let rules: [WordRule]
  let weights: LetterWeights

  var generator: BoardGenerator {
    BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, rules: rules, filler: weights,
      downWords: 1...2, attempts: 4, fillsPerAttempt: 10)
  }
}
