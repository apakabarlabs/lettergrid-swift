import Testing

@testable import LetterGrid

struct LayoutTests {
  @Test func crossingWordsStayCrossedOnTheCompletedBoard() throws {
    let generator = BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down],
      filler: try LetterWeights(["x": 1, "y": 1, "z": 1]), downWords: 1...1)
    let words = ["CAT", "TAP", "DOG"]
    let board = try generator.board(for: words, seed: 3)
    let cells = board.placements.flatMap(\.cells)
    #expect(Set(cells).count < cells.count)
    #expect(board.rows == 5 && board.columns == 5)
    #expect(board.placements.map(\.word) == words)
    for word in words {
      #expect(board.occurrences(of: word, along: [.right, .down]) == 1)
    }
  }

  @Test func sampledCatTapDogLayoutsShareLettersWithoutExtraRows() throws {
    let builder = LayoutBuilder(
      columns: 5, minimumRows: 5, directions: [.right, .down], downWords: 1...1)
    for seed: UInt64 in 1...100 {
      var random = SeededRandom(seed: seed)
      let layout = try #require(
        builder.lowestLayout(for: ["CAT", "TAP", "DOG"], tries: 40, using: &random))
      #expect(layout.rows == 5)
      #expect(layout.sharedCells > 0, "seed \(seed)")
      #expect(layout.placements.map(\.word) == ["CAT", "TAP", "DOG"])
      #expect(layout.placements.filter { $0.direction == .down }.count == 1)
    }
  }

  @Test func sharedCellsCountExtraUsesIncludingMultipleWordsAtOneCell() {
    let layout = Layout(
      rows: 3,
      placements: [
        Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right),
        Placement(word: "CUP", start: Cell(row: 0, column: 0), direction: .down),
        Placement(word: "CAR", start: Cell(row: 0, column: 0), direction: .downRight),
      ])
    #expect(layout.sharedCells == 2)
  }
}
