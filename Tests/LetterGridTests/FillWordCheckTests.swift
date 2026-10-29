import Testing

@testable import LetterGrid

struct FillWordCheckTests {
  @Test func everyTrialMatchesAFullSearchAcrossBacktrackingAndRuleKinds() {
    let alphabet = Array("ABCDEFGHIJ")
    let large = Set(
      alphabet.flatMap { a in
        alphabet.flatMap { b in alphabet.map { String([a, b, $0]) } }
      })
    let small: Set<String> = ["AXD", "DAQ", "DXA", "CAT", "DOG", "SUN", "A", "AAAAAAAAD"]
    for (columns, rows) in [(5, 5), (7, 6)] {
      let board = FillTestBoard.make(words: ["CAT", "DOG", "SUN"], columns: columns, rows: rows)
      for words in [small, large.union(small)] {
        let index = WordIndex(words)
        for rules in [
          [WordRule(startDirections: [.right, .down], turns: 0)],
          [WordRule(startDirections: Direction.allCases, turns: 0)],
          [WordRule(startDirections: [.right, .down], turns: 1)],
        ] {
          compare(board: board, index: index, rules: rules)
        }
      }
    }
  }

  @Test(arguments: [111, 112, 149, 150])
  func theIncrementalAndFullSearchBudgetBoundariesMatchTheOracle(rows: Int) {
    let letters = Array(repeating: Array(repeating: Character("A"), count: 224), count: rows)
    let board = Board(letters: letters, placements: [])
    let index = WordIndex(["AAAB"])
    let rules = [WordRule(startDirections: [.right], turns: 0)]
    let full = board.strayWordCount(in: index, rules: rules, lessThan: 1)
    #expect(full == (rows < 150 ? 0 : Int.max))
    let check = FillWordCheck(
      board: board, index: index, rules: rules, fixed: board.placementLetters)
    #expect(
      check.isClean(
        filling: Cell(row: rows - 1, column: 223),
        letters: letters.map { $0.map(Optional.some) }) == (full == 0))
  }

  @Test func aFixedConflictIsStillRejectedWhenTheChangedCellCannotTouchIt() {
    let board = FillTestBoard.make(words: ["CAT", "DOG", "SUN"], rowSpacing: 1)
    var letters = board.placementLetters
    let index = WordIndex(["CDS"])
    let rules = [WordRule(startDirections: [.down], turns: 0)]
    let check = FillWordCheck(board: board, index: index, rules: rules, fixed: letters)
    let changed = Cell(row: 4, column: 4)
    letters[changed.row][changed.column] = "X"
    #expect(!check.isClean(filling: changed, letters: letters))
    #expect(
      board.strayWordCount(in: index, rules: rules, letters: { letters[$0.row][$0.column] }) == 1)
  }

  private func compare(board: Board, index: WordIndex, rules: [WordRule]) {
    var letters = board.placementLetters
    let check = FillWordCheck(board: board, index: index, rules: rules, fixed: letters)
    let empty = (0..<board.rows).flatMap { row in
      (0..<board.columns).compactMap { column in
        letters[row][column] == nil ? Cell(row: row, column: column) : nil
      }
    }
    var random = SeededRandom(seed: 37)
    var position = 0
    let candidates = Array("ADXQZ")
    for _ in 0..<300 {
      if position == empty.count || (position > 0 && Bool.random(using: &random)) {
        position -= 1
        let cell = empty[position]
        letters[cell.row][cell.column] = nil
      }
      let cell = empty[position]
      letters[cell.row][cell.column] = candidates.randomElement(using: &random)
      let expected =
        board.strayWordCount(
          in: index, rules: rules, lessThan: 1, letters: { letters[$0.row][$0.column] }) == 0
      #expect(check.isClean(filling: cell, letters: letters) == expected)
      if expected {
        position += 1
      } else {
        letters[cell.row][cell.column] = nil
      }
    }
  }
}
