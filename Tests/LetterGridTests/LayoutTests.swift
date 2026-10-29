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

  @Test func everySeedOfCatTapDogSharesLettersWithoutExtraRows() throws {
    let request = try BoardGenerator(
      columns: 5, rows: 5, directions: [.right, .down],
      filler: try LetterWeights(["x": 1, "y": 1, "z": 1]), downWords: 1...1
    ).request(for: ["CAT", "TAP", "DOG"])
    for seed: UInt64 in 1...100 {
      let board = request.board(seed: seed)
      let cells = board.placements.flatMap(\.cells)
      #expect(board.rows == 5)
      #expect(Set(cells).count < cells.count, "seed \(seed)")
      #expect(board.placements.map(\.word) == ["CAT", "TAP", "DOG"])
      #expect(board.placements.filter { $0.direction == .down }.count == 1)
    }
  }
}
