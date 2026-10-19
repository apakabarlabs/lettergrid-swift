import Testing

@testable import LetterGrid

struct BoardFillerTests {
  private func filler(
    columns: Int, rows: Int, placements: [Placement], dictionary: Set<String>
  ) -> BoardFiller {
    BoardFiller(
      layout: Layout(rows: rows, placements: placements), columns: columns,
      directions: [.right, .down], dictionary: WordIndex(dictionary),
      targets: WordIndex(Set(placements.map(\.word))))
  }

  @Test func aFixedCrossingConflictNeedsNoFillerChoices() throws {
    let filler = filler(
      columns: 3, rows: 2,
      placements: [
        Placement(word: "AB", start: Cell(row: 0, column: 0), direction: .down),
        Placement(word: "CD", start: Cell(row: 0, column: 1), direction: .down),
      ], dictionary: ["AC"])
    var random = SeededRandom(seed: 1)
    var untouched = random

    #expect(filler.fill(with: try LetterWeights(["q": 1]), attempts: 1, using: &random) == nil)
    #expect(random.next() == untouched.next())
  }

  @Test func aTargetInsideAnotherPlacementIsStillADuplicate() throws {
    let filler = filler(
      columns: 5, rows: 2,
      placements: [
        Placement(word: "THERE", start: Cell(row: 0, column: 0), direction: .right),
        Placement(word: "HER", start: Cell(row: 1, column: 0), direction: .right),
      ], dictionary: ["THE", "HER"])
    var random = SeededRandom(seed: 1)

    #expect(filler.fill(with: try LetterWeights(["q": 1]), attempts: 1, using: &random) == nil)
  }

  @Test func fixedLettersAheadOfTheBlankCompleteAForbiddenWord() throws {
    let filler = filler(
      columns: 3, rows: 2,
      placements: [
        Placement(word: "AX", start: Cell(row: 0, column: 0), direction: .down),
        Placement(word: "BY", start: Cell(row: 0, column: 2), direction: .down),
      ], dictionary: ["ABB"])
    var random = SeededRandom(seed: 1)
    let board = try #require(
      filler.fill(with: LetterWeights(["b": 1_000, "c": 1]), attempts: 1, using: &random))

    #expect(board[Cell(row: 0, column: 1)] == "C")
    #expect(board.strayWords(of: ["ABB"], along: [.right, .down]).isEmpty)
  }

  @Test func anAllowedPrefixDoesNotExemptTheLongerWord() throws {
    let filler = filler(
      columns: 6, rows: 2,
      placements: [Placement(word: "THERE", start: Cell(row: 0, column: 0), direction: .right)],
      dictionary: ["THE", "THERE", "THEREX"])
    var random = SeededRandom(seed: 1)
    let board = try #require(
      filler.fill(with: LetterWeights(["x": 1_000, "y": 1]), attempts: 1, using: &random))

    #expect(board[Cell(row: 0, column: 5)] == "Y")
    #expect(board.strayWords(of: ["THE", "THERE", "THEREX"], along: [.right, .down]).isEmpty)
  }

  @Test func aDeadEndBacktracksToAnEarlierCell() throws {
    let filler = filler(
      columns: 3, rows: 2,
      placements: [Placement(word: "AC", start: Cell(row: 0, column: 2), direction: .down)],
      dictionary: ["BAA", "BBA"])
    var random = SeededRandom(seed: 1)
    let board = try #require(
      filler.fill(with: LetterWeights(["a": 1, "b": 1_000]), attempts: 1, using: &random))

    #expect(board[Cell(row: 0, column: 0)] == "A")
    #expect(board.strayWords(of: ["BAA", "BBA"], along: [.right, .down]).isEmpty)
    #expect(board.occurrences(of: "AC", along: [.right, .down]) == 1)
  }

  @Test func anImpossibleAlphabetStopsWithNoBoard() throws {
    let filler = filler(
      columns: 4, rows: 2,
      placements: [Placement(word: "BB", start: Cell(row: 0, column: 0), direction: .down)],
      dictionary: ["AAA"])
    var random = SeededRandom(seed: 1)

    #expect(filler.fill(with: try LetterWeights(["a": 1]), attempts: 1, using: &random) == nil)
  }

  @Test func dictionaryInsertionOrderDoesNotChangeTheBoard() throws {
    let words = ["AAA", "ABA", "BAA", "BBB"]
    let placements = [
      Placement(word: "SUN", start: Cell(row: 0, column: 0), direction: .right)
    ]
    let first = filler(columns: 4, rows: 3, placements: placements, dictionary: Set(words))
    let second = filler(
      columns: 4, rows: 3, placements: placements, dictionary: Set(words.reversed()))
    var firstRandom = SeededRandom(seed: 2)
    var secondRandom = firstRandom
    let weights = try LetterWeights(["a": 4, "b": 2, "q": 1])

    let firstBoard = try #require(first.fill(with: weights, attempts: 1, using: &firstRandom))
    let secondBoard = try #require(second.fill(with: weights, attempts: 1, using: &secondRandom))
    #expect(firstBoard == secondBoard)
  }
}
