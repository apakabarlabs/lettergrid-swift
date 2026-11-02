import Testing

@testable import LetterGrid

struct RunFreeFillTests {
  @Test func aPairPreferenceCannotRejectAnOtherwisePlayableField() throws {
    let board = try Board(
      validating: [Array("XXXXXXXXXXXX"), Array("ABXXXXXXXXXX")],
      placements: [
        Placement(word: "AB", start: Cell(row: 1, column: 0), direction: .right)
      ])
    let filled = try #require(
      RunFreeFill(
        board: board, weights: LetterWeights(["X": 1, "Y": 1, "Z": 1]),
        rules: [WordRule(startDirections: [.right])], conditionalCharacters: []
      ).filled(seed: 1))
    let runs = LetterRuns(placements: filled.placements, columns: filled.columns, rows: filled.rows)
    #expect(!runs.containsForbiddenRun(in: filled.letters.map { $0.map(Optional.some) }))
    #expect(filled.hasAddedEqualPair)
  }

  @Test func aConditionalCopyMovesAwayFromItsTargetLetter() throws {
    let original = try Board(
      validating: [Array("AÉÉXX")],
      placements: [Placement(word: "AÉ", start: Cell(row: 0, column: 0), direction: .right)])
    let fill = RunFreeFill(
      board: original, weights: try LetterWeights(["X": 1, "Y": 1, "É": 1]),
      rules: [WordRule(startDirections: [.right])], conditionalCharacters: ["É"])
    for seed in UInt64(100)..<108 {
      let board = try #require(fill.filled(seed: seed))
      let row = board.letters[0]
      #expect(zip(row, row.dropFirst()).allSatisfy { $0 != $1 }, "seed \(seed)")
      #expect(row.dropFirst(2).contains("É"), "seed \(seed)")
    }
  }
}
